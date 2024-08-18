require "./container"
require "./cgroups"

module Crysco::CliOptions
  enum SubCommand
    None
    Run
    Exec
  end

  def self.get : Tuple(SubCommand, Log::Severity, ContainerConfig)
    uid : LibC::UidT = 0
    mnt : String | Nil = nil
    cmd : String | Nil = nil
    subcommand = SubCommand::None
    cmd_args = [] of String
    log_level = Log::Severity::Info
    existing_container_id = ""
    exec_in_existing = false
    use_overlay = false

    optparse = OptionParser.parse do |parser|
      parser.on("run", "run a command in a new container") do
        subcommand = SubCommand::Run
        parser.banner = "Usage: crysco run [OPTIONS] COMMAND [-- ARGS]"
        parser.on("-u UID", "--uid=UID", "uid and gid of the user in the container") { |opt_uid| uid = opt_uid.to_u32 }
        parser.on("-m DIR", "--mount=DIR", "directory to mount as root in the container") { |opt_mnt| mnt = opt_mnt }
        parser.on("-o", "--overlay", "use an overlay to prevent modifications to mounted directory") { |opt_overlay| use_overlay = true }
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

      parser.on("exec", "execute a command in an existing container") do
        subcommand = SubCommand::Exec
        parser.on("-c ID", "--in-container=ID", "exec command in existing container") { |opt_cgroup_id| existing_container_id = opt_cgroup_id }
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

    errors = [] of String

    if subcommand.none?
      puts optparse
      exit
    end

    if subcommand.run?
      errors << "--mount is required" if mnt.nil?
    end

    if subcommand.run? || subcommand.exec?
      errors << "a command is required" if cmd.nil?
    end

    if errors.size > 0
      errors.each do |err|
        puts err
      end
      exit 1
    end

    if existing_container_id.size > 0
      container_hostname = "crysco_#{existing_container_id}"
      # this error handling isn't really dealing with command line arguments
      # so it should probably go somewhere else
      unless Cgroups.exists?(container_hostname)
        Log.error { "Container '#{existing_container_id}' does not exist" }
        exit 1
      end
      exec_in_existing = true
    else
      container_hostname = Hostname.generate
    end

    if subcommand.exec?
      mnt = ""
    end
    
    config = ContainerConfig.new(
      uid, container_hostname, cmd.as(String), cmd_args,
      Path[mnt.as(String)].normalize, exec_in_existing,
      use_overlay
    )

    return {subcommand, log_level, config}
  end
end