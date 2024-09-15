require "socket/common"
require "socket"

class Socket
  getter family : Family | LibC::UShort
  getter protocol : Protocol | NetlinkProtocol
  AF_NETLINK = 16u16

  enum NetlinkProtocol
    ROUTE            = 0       # Routing/device hook                               
    UNUSED           = 1       # Unused number                                     
    USERSOCK         = 2       # Reserved for user mode socket protocols   
    FIREWALL         = 3       # Unused number, formerly ip_queue                  
    SOCK_DIAG        = 4       # socket monitoring                                 
    NFLOG            = 5       # netfilter/iptables ULOG
    XFRM             = 6       # ipsec
    SELINUX          = 7       # SELinux event notifications
    ISCSI            = 8       # Open-iSCSI
    AUDIT            = 9       # auditing
    FIB_LOOKUP       = 10
    CONNECTOR        = 11
    NETFILTER        = 12      # netfilter subsystem
    IP6_FW           = 13
    DNRTMSG          = 14      # DECnet routing messages (obsolete)
    KOBJECT_UEVENT   = 15      # Kernel messages to userspace
    GENERIC          = 16
    # leave room for NETLINK_DM (DM Events)
    SCSITRANSPORT    = 18      # SCSI Transports
    ECRYPTFS         = 19
    RDMA             = 20
    CRYPTO           = 21      # Crypto layer
    SMC              = 22      # SMC monitoring
  end

  private def initialize(@family : LibC::UShort, @type : Type, @protocol : NetlinkProtocol, blocking = false)
    fd = create_handle(family, type, protocol, blocking)
    @volatile_fd = Atomic.new(fd)
    @closed = false
    initialize_handle(fd)

    self.sync = true
    unless blocking
      self.blocking = false
    end
  end

  private def create_handle(family : LibC::UShort, type : Type, protocol : NetlinkProtocol, blocking = false)
    fd = LibC.socket(family, type, protocol)
    raise ::Socket::Error.from_errno("Failed to create socket") if fd == -1
    fd
  end

  def self.netlink(protocol : NetlinkProtocol)
    new(AF_NETLINK, Type::RAW, protocol)
  end
end
