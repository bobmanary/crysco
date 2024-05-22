# partial bindings for seccomp library
@[Link("seccomp")]
lib Libseccomp
  type SeccompFilterContext = Void*

  enum ComparisonOp # scmp_compare
    SCMP_CMP_MIN = 0
    SCMP_CMP_NE = 1		# not equal
    SCMP_CMP_LT = 2		# less than
    SCMP_CMP_LE = 3		# less than or equal
    SCMP_CMP_EQ = 4		# equal
    SCMP_CMP_GE = 5		# greater than or equal
    SCMP_CMP_GT = 6		# greater than
    SCMP_CMP_MASKED_EQ = 7		# masked equality
    SCMP_CMP_MAX
  end

  struct ArgComparison # scmp_arg_cmp
    arg : LibC::UInt # argument index
    op : ComparisonOp
    datum_a : LibC::UInt64T # mask
    datum_b : LibC::UInt64T # value
  end

  enum FilterAttribute # scmp_filter_attr (SCMP_FLTATTR_*)
    MIN          = 0
    ACT_DEFAULT  = 1 # default filter action
    ACT_BADARCH  = 2 # bad architecture action
    CTL_NNP      = 3 # set NO_NEW_PRIVS on filter load
    CTL_TSYNC    = 4 # sync threads on filter load
    API_TSKIP    = 5 # allow rules with a -1 syscall
    CTL_LOG      = 6 # log not-allowed actions
    CTL_SSB      = 7 # disable SSB mitigation
    CTL_OPTIMIZE = 8 # filter optimization level:
                     #  0 - currently unused
                     #  1 - rules weighted by priority and complexity (DEFAULT)
                     #  2 - binary tree sorted by syscall number
    API_SYSRAWRC = 9 # return the system return codes
    MAX
  end

  fun seccomp_init(def_action : UInt32) : SeccompFilterContext
  # variadic arguments should be 0 or more instances of ArgComparison, with
  # arg_cnt set to the number of ArgComparison instances
  fun seccomp_rule_add(ctx : SeccompFilterContext, action : UInt32, syscall : LibC::Int, arg_cnt : LibC::UInt, ...) : LibC::Int
  fun seccomp_attr_set(ctx : SeccompFilterContext, attr : FilterAttribute, value : LibC::UInt) : LibC::Int
  fun seccomp_load(ctx : SeccompFilterContext) : LibC::Int
  fun seccomp_release(ctx : SeccompFilterContext)
end
