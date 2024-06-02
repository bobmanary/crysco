require "socket"
require "option_parser"
require "log"
require "./mount"
require "./syscalls"
require "./container"
require "./cgroups"
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

    optparse = OptionParser.parse do |parser|
      parser.on("run", "run a command in a container") do
        cmd_run = true
        parser.banner = "Usage: crysco run [OPTIONS] COMMAND [-- ARGS]"
        parser.on("-u UID", "--uid=UID", "uid and gid of the user in the container") { |opt_uid| uid = opt_uid.to_i }
        parser.on("-m DIR", "--mount=DIR", "directory to mount as root in the container") { |opt_mnt| mnt = opt_mnt }
        parser.unknown_args do |before, after|
          unless before.empty?
            cmd = before.first
          else
            puts "A command is required.\nSee 'crysco run --help'"
            exit 1
          end

          cmd_args = after
        end
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit
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

    log_backend = Log::IOBackend.new(dispatcher: Log::DispatchMode::Sync)
    Log.setup(log_level, log_backend) # Log debug and above for all sources to using a custom backend


    if mnt.nil? || cmd.nil?
      errors = [] of String
      errors << "--mount is required" if mnt.nil?
      errors << "--cmd is required" if cmd.nil?

      errors.each do |err|
        puts err
      end
      exit 1
    end

    unless Syscalls.geteuid == 0
      Log.warn { "crysco should be run as root" }
    end

    sockets = UNIXSocket.pair(Socket::Type::SEQPACKET)

    config = ContainerConfig.new(uid, sockets[1], "mycontainer", cmd.as(String), cmd_args, Path[mnt.as(String)].normalize)

    cleanup = -> do
      Log.debug {"Freeing sockets..."}
      sockets[0].close
      sockets[1].close
      Log.debug {"Freeing cgroups..."}
      Cgroups.free(config.hostname)
    end

    Log.info { "Initializing container..." }
    child = Container.spawn(config, log_level)

    Log.info { "Initializing cgroups..." }
    if !Cgroups.apply(config.hostname, child.pid)
      Log.fatal { "Failed to initialize cgroups" }
      cleanup.call
      exit 1
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