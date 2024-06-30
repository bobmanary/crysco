require "socket"
require "option_parser"
require "log"
require "./mount"
require "./syscalls"
require "./container"
require "./cgroups"
require "./hostname"
require "./user_namespace"

module Crysco
  VERSION = "0.1.0"

  def self.main
    uid = 0
    mnt : String | Nil = nil
    cmd : String | Nil = nil
    cmd_run = false
    cmd_args = [] of String
    log_level = Log::Severity::Info
    existing_cgroup_id = ""
    exec_in_existing = false

    optparse = OptionParser.parse do |parser|
      parser.on("run", "run a command in a container") do
        cmd_run = true
        parser.banner = "Usage: crysco run [OPTIONS] COMMAND [-- ARGS]"
        parser.on("-u UID", "--uid=UID", "uid and gid of the user in the container") { |opt_uid| uid = opt_uid.to_i }
        parser.on("-m DIR", "--mount=DIR", "directory to mount as root in the container") { |opt_mnt| mnt = opt_mnt }
        parser.on("-c ID", "--in-container=ID", "exec command in existing container") { |opt_cgroup_id| existing_cgroup_id = opt_cgroup_id }
        parser.unknown_args do |before, after|
          unless before.empty?
            cmd = before.first
          else
            puts "A command is required.\nSee 'crysco run --help'"
            exit 1
          end

          cmd_args = after
        end
      end
      parser.banner = "Usage: sudo ./crysco [OPTIONS] command [ARGS]"
      parser.on("-v", "--verbose", "enable verbose output") { log_level = Log::Severity::Debug }
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end
      parser.missing_option do |option|
        puts "missing option for #{option}"
        exit 1
      end
    end

    if !cmd_run
      puts optparse
      exit
    end

    # log synchronously to reduce garbled parent/child output
    log_backend = Log::IOBackend.new(dispatcher: Log::DispatchMode::Sync)
    Log.setup(log_level, log_backend)


    if mnt.nil? || cmd.nil?
      errors = [] of String
      errors << "--mount is required" if mnt.nil?
      errors << "--cmd is required" if cmd.nil?

      errors.each do |err|
        puts err
      end
      exit 1
    end

    if existing_cgroup_id.size > 0
      hostname = "crysco_#{existing_cgroup_id}"
      unless Cgroups.exists?(hostname)
        Log.error { "Container '#{existing_cgroup_id}' does not exist" }
        exit 1
      end
      exec_in_existing = true
    else
      container_hostname = Hostname.generate
    end

    unless Syscalls.geteuid == 0
      Log.warn { "crysco should be run as root" }
    end

    sockets = UNIXSocket.pair(Socket::Type::SEQPACKET)

    config = ContainerConfig.new(uid, sockets[1], Hostname.generate, cmd.as(String), cmd_args, Path[mnt.as(String)].normalize)

    cleanup = -> do
      Log.debug {"Freeing sockets..."}
      sockets[0].close
      sockets[1].close
      Log.debug {"Freeing cgroups..."}
      Cgroups.free(config.hostname)
    end

    Log.info { "Initializing container..." }
    child = Container.spawn(config, log_level)

    if exec_in_existing
      Log.info { "Entering existing cgroup..."}
      if !Cgroups.join(config.hostname, child.pid)
        Log.fatal { "Failed to join cgroup" }
        exit 1
      end
    else
      Log.info { "Initializing cgroup..." }
      if !Cgroups.initialize(config.hostname, child.pid)
        Log.fatal { "Failed to initialize cgroup" }
        cleanup.call
        exit 1
      end
    end

    Log.info { "Configuring user namespace..." }
    unless UserNamespace.prepare_mappings(child, sockets[0])
      Log.fatal {"Failed to set user namespace mappings, stopping container..."}
      cleanup.call
      exit 1
    end

    Log.info {"Waiting for container to exit..."}
    child.wait
    Log.debug {"Container exited."}

    cleanup.call
  end
end

Crysco.main