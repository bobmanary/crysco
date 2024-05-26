require "./syscalls"
require "./hostname"
require "./user_namespace"
require "./sec"
require "log"

module Crysco
  Log.define_formatter ChildFormatter, "child: #{severity}: #{message}"

  class ContainerConfig
    property uid : Int32
    property child_socket : UNIXSocket
    property hostname : String
    property cmd : String
    property arg : String?
    property mnt : Path

    def initialize(@uid, @child_socket, @hostname, @cmd, @arg, @mnt)
    end
  end

  class Container
    getter pid : Int32
    @process : Crystal::System::Process

    private def initialize(@pid)
      @process = Crystal::System::Process.new(@pid)
    end

    # Creates container (process) with different properties than its parent
    # e.g. mount to different dir, different hostname, etc...
    # All these requirements are specified by the flags we pass to clone()
    def self.spawn(config : ContainerConfig, log_level : Log::Severity) : Container
      # The flags specify what the cloned process can do.
      # These allow some control overrmounts, pids, IPC data structures, network
      # devices and hostname.
      flags = Syscalls::ProcFlags::CLONE_NEWNS | Syscalls::ProcFlags::CLONE_NEWCGROUP |
              Syscalls::ProcFlags::CLONE_NEWPID | Syscalls::ProcFlags::CLONE_NEWIPC |
              Syscalls::ProcFlags::CLONE_NEWNET | Syscalls::ProcFlags::CLONE_NEWUTS |
              Syscalls::ProcFlags::SIGCHLD;
      # SIGCHLD lets us wait on the child process.

      # unused but necessary
      stack = Pointer(Void).null
      parent_tid = Pointer(LibC::Int).null
      child_tid = Pointer(LibC::Int).null
      tls = Pointer(Void).null

      Log.debug { "cloning process..." }

      # clone is a superset of fork's functionality, so the same considerations as
      # calling fork in Crystal apply here.
      new_pid = Syscalls.clone(flags, stack, parent_tid, child_tid, tls)

      case new_pid
      when -1
        Log.error { "Failed to clone" }
        exit 2
      when 0
        # new child process with pid 1 inside namespace
        # this return is never reached (?)
        puts log_level
        backend_with_formatter = Log::IOBackend.new(formatter: ChildFormatter, dispatcher: Log::DispatchMode::Sync)
        Log.setup(log_level, backend_with_formatter) # Log debug and above for all sources to using a custom backend

        container = new(new_pid)
        unless container.child_start(config)
          Log.error {"Failed to start container"}
          exit 1
        end

        exit 0
        return container
      else
        # this is the parent process, and it received the pid of the new process
        config.child_socket.close
        return new(new_pid)
      end
    end

    def wait
      @process.wait
    end

    def child_start(config : ContainerConfig) : Bool
      Log.debug {"starting container"}
      Log.debug {"setting hostname, mounts, user namespace, capabilities and syscalls..."}

      unless (
        Hostname.set(config.hostname) &&
        Mount.set(config.mnt) &&
        UserNamespace.init(0u32, config.child_socket) &&
        Sec.set_capabilities() &&
        Sec.set_seccomp_filters()
      )
        Log.debug {"Failed to set container properties"}
        return false
      end

      Log.debug {"Closing container socket..."}
      config.child_socket.close()

      Log.debug {"Executing command #{config.cmd} #{config.arg} from directory #{config.mnt} in container..."}
      Log.info {"### CONTAINER STARTING - type 'exit' to quit ###"}

      args = config.arg.nil? ? [] of String : [config.arg.as(String)]
      Process.exec(config.cmd, args, shell: false)

      return true
    end
  end
end
