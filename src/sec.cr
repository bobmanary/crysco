require "./security/constants"
require "./security/capabilities"
require "./security/seccomp"

module Crysco::Sec
  include Security::Constants

  def self.set_capabilities() : Bool
    Log.debug {"Setting capabilities..."}
    capabilities_to_drop = [
      Cap::AUDIT_CONTROL,   Cap::AUDIT_READ,   Cap::AUDIT_WRITE, Cap::BLOCK_SUSPEND,
      Cap::DAC_READ_SEARCH, Cap::FSETID,       Cap::IPC_LOCK,    Cap::MAC_ADMIN,
      Cap::MAC_OVERRIDE,    Cap::MKNOD,        Cap::SETFCAP,     Cap::SYSLOG,
      Cap::SYS_ADMIN,       Cap::SYS_BOOT,     Cap::SYS_MODULE,  Cap::SYS_NICE,
      Cap::SYS_RAWIO,       Cap::SYS_RESOURCE, Cap::SYS_TIME,    Cap::WAKE_ALARM
    ]

    mgr = Security::Capabilities::CapabilityManager.new

    Log.debug {"Dropping bounding capabilities..."}
    if !mgr.drop_from_bounding_set(capabilities_to_drop)
      Log.error {"Failed to drop bounding capabilities"}
      return false
    end

    Log.debug {"Dropping inheritable capabilities..."}
    if !mgr.drop_from_inheritable_set(capabilities_to_drop)
      Log.error {"Failed to drop inheritable capabilities"}
      return false
    end

    Log.debug {"Capabilities set."}
    true
  end

  def self.set_seccomp_filters() : Bool
    Security::Seccomp.block_syscalls
  end
end
