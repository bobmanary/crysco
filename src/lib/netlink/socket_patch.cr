require "socket/common"
# require "./netlink_address"
require "socket"

lib SocketPatch
  struct SockaddrNl
    sa_family : LibC::SaFamilyT
    nl_pad : LibC::UShort
    nl_pid : UInt32
    nl_groups : UInt32
  end

  # fun bind(fd : LibC::Int, addr : SockaddrNl*, len : LibC::SocklenT) : LibC::Int
end


class Socket
  AF_NETLINK = 16u16

  getter family : Family | LibC::UShort
  getter protocol : Protocol | NetlinkProtocol

  abstract struct Address
    getter family : Family | LibC::UShort
    # copy of Socket.class.from with added NLAddress case
    def self.from(sockaddr : LibC::Sockaddr*, addrlen) : Address
      case family = sockaddr.value.sa_family
      when Family::INET6
        IPAddress.new(sockaddr.as(LibC::SockaddrIn6*), addrlen.to_i)
      when Family::INET
        IPAddress.new(sockaddr.as(LibC::SockaddrIn*), addrlen.to_i)
      when Family::UNIX
        UNIXAddress.new(sockaddr.as(LibC::SockaddrUn*), addrlen.to_i)
      when AF_NETLINK
        NLAddress.new(sockaddr.as(SocketPatch::SockaddrNl*), addrlen.to_i)
      else
        raise "Unsupported family type: #{family}"
      end
    end
  end

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

  struct NLAddress < Address
    getter pid : UInt32
    getter groups : UInt32

    def initialize(sockaddr : SocketPatch::SockaddrNl*, @size)
      @family = AF_NETLINK
      @pid = sockaddr.value.nl_pid
      @groups = sockaddr.value.nl_groups
    end

    def to_unsafe : LibC::Sockaddr*
      sockaddr = Pointer(SocketPatch::SockaddrNl).malloc
      sockaddr.value.sa_family = @family
      sockaddr.nl_pid = @pid
      sockaddr.value.nl_groups = @groups
      sockaddr.as(LibC::Sockaddr*)
    end
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

  def bind(addr : SocketPatch::SockaddrNl)
    system_bind(addr, addr.to_s) { |errno| raise errno }
  end

  private def system_bind(addr : SocketPatch::SockaddrNl, addrstr, &)
    unless LibC.bind(fd, pointerof(addr).as(Pointer(LibC::Sockaddr)), sizeof(SocketPatch::SockaddrNl)) == 0
      yield ::Socket::BindError.from_errno("Could not bind to '#{addrstr}'")
    end
  end
end
