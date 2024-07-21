require "socket"
require "option_parser"
require "log"
require "./mount"
require "./syscalls"
require "./container"
require "./cgroups"
require "./hostname"
require "./user_namespace"
require "./cli_options"

module Crysco
  VERSION = "0.1.0"

  def self.main
    subcommand, log_level, config = CliOptions.get

    # log synchronously to reduce garbled parent/child output
    log_backend = Log::IOBackend.new(dispatcher: Log::DispatchMode::Sync)
    Log.setup(log_level, log_backend)

    unless Syscalls.geteuid == 0
      Log.warn { "crysco should be run as root" }
    end

    cleanup = -> do
      Log.debug {"Freeing sockets..."}
      config.child_socket.close
      config.parent_socket.close
      unless config.use_existing
        Log.debug {"Freeing cgroups..."}
        Cgroups.free(config.hostname)
      end
    end

    Log.info { "Initializing container..." }
    child = Container.spawn(config, log_level)

    if config.use_existing
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

      Log.info { "Configuring user namespace..." }
      unless UserNamespace.prepare_mappings(child, config.parent_socket)
        Log.fatal {"Failed to set user namespace mappings, stopping container..."}
        cleanup.call
        exit 1
      end
    end

    Log.info {"Waiting for container to exit..."}
    child.wait
    Log.debug {"Container exited."}

    cleanup.call
  end
end

Crysco.main