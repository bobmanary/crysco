require "../lib/libseccomp"
require "../syscalls"
require "log"

# An incomplete, thin wrapper for libseccomp
module Crysco::Security::Seccomp
  # TODO: move to Libseccomp bindings/enums?
  # copied out of various C headers
  SCMP_ACT_ALLOW = 0x7fff0000u32
  EPERM = 1u16
  SCMP_ACT_ERRNO_EPERM = (0x00050000u32 | (EPERM & 0x0000ffffu32))
  SEC_SCMP_FAIL        = (0x00050000u32 | ((1) & 0x0000ffffu32))

  class SeccompContext
    def initialize(action)
      @ctx = Libseccomp.seccomp_init(action)
    end

    def allow_syscall(syscall : LibC::Int)
      Libseccomp.seccomp_rule_add(@ctx, SCMP_ACT_ALLOW, syscall, 0) == 0
    end

    def block_syscall(syscall : Syscall::Code, *args : Libseccomp::ArgComparison)
      Libseccomp.seccomp_rule_add(@ctx, SEC_SCMP_FAIL, syscall, args.size, *args) == 0
    end

    def block_syscall(syscall : Syscall::Code)
      Libseccomp.seccomp_rule_add(@ctx, SEC_SCMP_FAIL, syscall, 0) == 0
    end

    def set_attribute(attr : Libseccomp::FilterAttribute, value : LibC::UInt)
      Libseccomp.seccomp_attr_set(@ctx, attr, value) == 0
    end

    def load
      Libseccomp.seccomp_load(@ctx) == 0
    end

    def finalize
      Libseccomp.seccomp_release(@ctx)
    end
  end

  macro syscall_num(name)
    ::Syscall::Code::{{name.stringify.upcase.id}}
  end

  def self.with_context(default_action : UInt32) : Nil
    ctx = SeccompContext.new(default_action)
    yield ctx
  end

  # Block sensitive system calls, based on Barco's list, which is in turn
  # based on Docker's list. Docker blocks all system calls by default and
  # then individually allows a (very large) list of calls, but we're
  # doing the opposite here for ease of implementation (I guess?)
  # - https://github.com/lucavallin/barco/blob/4300a67b38c7f2b158ec0cb221e1f3396ab65d1e/src/sec.c
  # - the Docker implementation is spread over like 4 repositories, but my rabbit hole
  #   started here: https://github.com/moby/moby/issues/42441
  def self.block_syscalls
    Log.debug {"Blocking specific system calls..."}

    # embed some single-use C constants as local variables:
    clone_newuser = Crysco::Syscalls::ProcFlags::CLONE_NEWUSER.to_u64
    # from /usr/include/x86_64-linux-gnu/bits/stat.h:
    s_isuid = 0o4000u64
    s_isgid = 0o2000u64
    # from /usr/include/asm-generic/ioctls.h:
    tiocsti = 0x5412u64

    # syscalls with one argument to filter by
    # Tuple(system call number, argument index, mask/value)
    blocked_syscalls_one_arg = [
      # Calls that allow creating new setuid / setgid executables.
      # The contained process could created a setuid binary that can be used
      # by an user to get root in absence of user namespaces.
      {syscall_num(chmod), 1, s_isuid},
      {syscall_num(chmod), 1, s_isgid},
      {syscall_num(fchmod), 1, s_isuid},
      {syscall_num(fchmod), 1, s_isgid},
      {syscall_num(fchmodat), 2, s_isuid},
      {syscall_num(fchmodat), 2, s_isgid},

      # Calls that allow contained processes to start new user namespaces
      # and possibly allow processes to gain new capabilities.
      {syscall_num(unshare), 0, clone_newuser},
      {syscall_num(clone), 0, clone_newuser},

      # Allows contained processes to write to the controlling terminal
      {syscall_num(ioctl), 1, tiocsti}
    ].map do |(syscall, arg_index, filter_value)|
      arg = Libseccomp::ArgComparison.new(
        arg: arg_index,
        op: Libseccomp::ComparisonOp::SCMP_CMP_MASKED_EQ,
        datum_a: filter_value,
        datum_b: filter_value
      )
      {syscall, arg}
    end

    blocked_syscalls_no_args = [
      # The kernel keyring system is not namespaced
      syscall_num(keyctl),
      syscall_num(add_key),
      syscall_num(request_key),

      # Before Linux 4.8, ptrace breaks seccomp
      syscall_num(ptrace),

      # Calls that let processes assign NUMA nodes. These could be used to deny
      # service to other NUMA-aware application on the host.
      syscall_num(mbind),
      syscall_num(migrate_pages),
      syscall_num(move_pages),
      syscall_num(set_mempolicy),

      # Alows userspace to handle page faults It can be used to pause execution
      # in the kernel by triggering page faults in system calls, a mechanism
      # often used in kernel exploits.
      syscall_num(userfaultfd),

      # This call could leak a lot of information on the host.
      # It can theoretically be used to discover kernel addresses and
      # uninitialized memory.
      syscall_num(perf_event_open),
    ]

    with_context(SCMP_ACT_ALLOW) do |ctx|
      blocked_syscalls_one_arg.each do |(syscall, arg)|
        unless ctx.block_syscall(syscall, arg)
          Log.error {"Failed to block syscall #{syscall.to_s}"}
          return false
        end
      end

      blocked_syscalls_no_args.each do |syscall|
        unless ctx.block_syscall(syscall)
          Log.error {"Failed to block syscall #{syscall.to_s}"}
          return false
        end
      end

      unless ctx.set_attribute(Libseccomp::FilterAttribute::CTL_NNP, 0)
        Log.error {"Failed to seccomp_attr_set to lock down setuid/setcap"}
        return false
      end

      unless ctx.load()
        Log.error {"Failed to load seccomp filters into kernel"}
        return false
      end
    end

    true
  end
end
