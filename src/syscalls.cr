module Crysco::Syscalls
  Syscall.def_syscall pivot_root, LibC::Int, new_root : UInt8*, put_old : UInt8*
  Syscall.def_syscall mount, LibC::Int, source : UInt8*, target : UInt8*, filesystemtype : UInt8*, mountflags : UInt32, data : UInt8*

  # For our purposes, we only need the clone syscall's flags argument
  # and return value.
  # stack should be Pointer(Void).null.
  # parent_tid and child_tid should be Pointer(LibC::Int).null.
  # tls should be Pointer(Void).null.
  Syscall.def_syscall clone, LibC::Int, flags : ProcFlags, stack : Void*, parent_tid : LibC::Int*, child_tid : LibC::Int*, tls : Void*

  # Syscall.def_syscall clone3, LibC::Long, cl_args : Clone3::CloneArgs*, size : LibC::SizeT
  Syscall.def_syscall geteuid, LibC::Int
  Syscall.def_syscall unshare, LibC::Int, flags : ProcFlags
  Syscall.def_syscall umount2, LibC::Int, target : UInt8*, flags : MountFlags
  Syscall.def_syscall prctl, LibC::Int, option : LibC::Int, arg2 : LibC::ULong, arg3 : LibC::ULong, arg4 : LibC::ULong, arg5 : LibC::ULong
  Syscall.def_syscall setns, LibC::Int, fd : LibC::Int, nstype : ProcFlags
  Syscall.def_syscall pidfd_open, LibC::Int, pid : LibC::PidT, flags : LibC::UInt

  @[Flags]
  enum MountFlags
    MNT_DETACH = 2
    MS_BIND    = 4096
    MS_REC     = 16384
    MS_PRIVATE = 1 << 18
  end

  @[Flags]
  enum ProcFlags# : LibC::ULongLong
    SIGCHLD           = 17

    # subset of flags from sys/bits/sched.h
    CLONE_NEWNS       = 0x00020000
    CLONE_NEWCGROUP   = 0x02000000
    CLONE_NEWUTS      = 0x04000000
    CLONE_NEWIPC      = 0x08000000
    CLONE_NEWUSER     = 0x10000000
    CLONE_NEWPID      = 0x20000000
    CLONE_NEWNET      = 0x40000000
    # CLONE_INTO_CGROUP = 0x200000000
  end

  lib Clone3
    struct CloneArgs
      # regular u64:
      flags, exit_signal : LibC::ULongLong

      # pointers cast to u64:
      pidfd, child_tid, parent_tid, stack, stack_size,
        tls, set_tid, set_tid_size, cgroup : LibC::ULongLong
    end
    CLARGS_SIZE = sizeof(CloneArgs).to_u64
  end
end
