require "./syscalls"
require "./hostname"
require "./user_namespace"
require "./sec"
require "log"

module Crysco
  Log.define_formatter ChildFormatter, "[child] #{severity}: #{message}"

  class ContainerConfig
    property uid : Int32
    property child_socket : UNIXSocket
    property hostname : String
    property cmd : String
    property args : Array(String)
    property mnt : Path
    property use_existing : Bool

    def initialize(@uid, @child_socket, @hostname, @cmd, @args, @mnt, @use_existing)
    end
  end

  class Container
    getter pid : Int32
    @process : Crystal::System::Process

    # The flags specify what the cloned process can do.
    # These allow some control overrmounts, pids, IPC data structures, network
    # devices and hostname.
    NAMESPACE_FLAGS = Syscalls::ProcFlags::CLONE_NEWNS | Syscalls::ProcFlags::CLONE_NEWCGROUP |
            Syscalls::ProcFlags::CLONE_NEWPID | Syscalls::ProcFlags::CLONE_NEWIPC |
            Syscalls::ProcFlags::CLONE_NEWNET | Syscalls::ProcFlags::CLONE_NEWUTS

    private def initialize(@pid)
      @process = Crystal::System::Process.new(@pid)
    end

    # Creates container (process) with different properties than its parent
    # e.g. mount to different dir, different hostname, etc...
    # All these requirements are specified by the flags we pass to clone()
    def self.spawn(config : ContainerConfig, log_level : Log::Severity) : Container

      # unused but necessary
      stack = Pointer(Void).null
      parent_tid = Pointer(LibC::Int).null
      child_tid = Pointer(LibC::Int).null
      tls = Pointer(Void).null

      Log.debug {"Cloning process..."}

      # if execing into an existing cgroup and namespaces, don't set any CLONE_NEW* flags
      # and call `setns` after the process is created to inherit the namespaces of one
      # of the existing processes.
      # SIGCHLD lets us wait() on the child process, but it's an invalid flag for `setns`.
      clone_flags = if config.use_existing
        Syscalls::ProcFlags::SIGCHLD
      else
        NAMESPACE_FLAGS | Syscalls::ProcFlags::SIGCHLD
      end

      # clone is a superset of fork's functionality, so the same considerations as
      # calling fork in Crystal apply here.
      # new_pid = Syscalls.clone(clone_flags, stack, parent_tid, child_tid, tls)

      clone_args = Syscalls::Clone3::CloneArgs.new
      clone_args.flags = clone_flags
      new_pid = Syscalls.clone3(pointerof(clone_args), Syscalls::Clone3::CLARGS_SIZE)

      case new_pid
      when -1
        Log.error {"Failed to clone"}
        exit 2
      when 0
        # new child process with pid 1 inside namespace
        backend_with_formatter = Log::IOBackend.new(formatter: ChildFormatter, dispatcher: Log::DispatchMode::Sync)
        Log.setup(log_level, backend_with_formatter) # Log debug and above for all sources to using a custom backend

        if config.use_existing
          pidfd = Cgroups.get_pid_fd(config.hostname)
          Log.debug {"Moving new process to namespaces for existing process..."}
          puts "PID a: #{Process.pid}"
          unless Syscalls.setns(pidfd, NAMESPACE_FLAGS) == 0
            raise RuntimeError.from_errno("Could not assign existing namespaces")
          end
          puts "PID b: #{Process.pid}"
        end

        container = new(new_pid)
        unless container.child_start(config)
          Log.error {"Failed to start container"}
          exit 1
        end

        exit 0
        # this return is never reached (?)
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
      Log.debug {"Starting container"}

      Log.debug {"Setting hostname, mounts, user namespace, capabilities and syscalls..."}
      properties_initialized = if config.use_existing
        Sec.set_capabilities() &&
        Sec.set_seccomp_filters()
      else
        Hostname.set(config.hostname) &&
        Mount.set(config.mnt) &&
        UserNamespace.init(0u32, config.child_socket) &&
        Sec.set_capabilities() &&
        Sec.set_seccomp_filters()
      end

      unless properties_initialized
        Log.debug {"Failed to set container properties"}
        return false
      end

      Log.debug {"Closing container socket..."}
      config.child_socket.close()

      Log.debug {"Executing command #{config.cmd} #{config.args.join(" ")} from directory #{config.mnt} in container..."}
      Log.info {"### CONTAINER STARTING - type 'exit' to quit ###"}
      Log.info {"Container ID: #{config.hostname}"}
      Process.exec(config.cmd, config.args, shell: false)

      return true
    end
  end
end
