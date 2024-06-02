require "./constants"
require "../syscalls"
require "../lib/libcap"

module Crysco::Security::Capabilities
  include Constants

  class CapabilityManager
    @cap_handle : LibCap::CapT

    def initialize
      @cap_handle = LibCap.cap_get_proc()
    end

    def finalize
      LibCap.cap_free(@cap_handle)
    end

    def drop_from_bounding_set(capabilities : Array(Cap)) : Bool
      capabilities.each do |capability|
        if Syscalls.prctl(PR_CAPBSET_DROP, capability.to_u32, 0u32, 0u32, 0u32) != 0
          return false
        end
      end

      true
    end

    def drop_from_inheritable_set(capabilities : Array(Cap)) : Bool
      caps = capabilities.map(&.to_u32)

      if LibCap.cap_set_flag(
        @cap_handle, LibCap::CapFlagT::CAP_INHERITABLE,
        caps.size, caps.to_unsafe, LibCap::CapFlagValueT::CAP_CLEAR
      ) != 0
        return false
      end

      if LibCap.cap_set_proc(@cap_handle) != 0
        return false
      end

      true
    end

  end
end
