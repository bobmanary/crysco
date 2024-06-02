@[Link("cap")]
lib LibCap
  # opaque handle
  type CapT = Void*

  enum CapFlagValueT
    CAP_CLEAR = 0
    CAP_SET   = 1
  end

  enum CapFlagT
    CAP_EFFECTIVE   = 0
    CAP_PERMITTED   = 1
    CAP_INHERITABLE = 2
  end

  fun cap_get_proc : CapT
  fun cap_set_proc(cap_p : CapT) : LibC::Int
  fun cap_set_flag(
    cap_p : CapT,
    flag : CapFlagT,
    num_cap : LibC::Int,
    caps : LibC::UInt*,
    value : CapFlagValueT
  ) : LibC::Int
  fun cap_free(obj_d : CapT) : LibC::Int
end
