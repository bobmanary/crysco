require "../msg_header"
require "../socket"

module Netlink
  module Protocol
    module Route

      # Link data attribute identifiers
      # translated from /usr/include/linux/if_link.h
      enum IFLA : UInt16
        UNSPEC
        ADDRESS
        BROADCAST
        IFNAME
        MTU
        LINK
        QDISC
        STATS
        COST
        PRIORITY
        MASTER
        WIRELESS # Wireless Extension event - see wireless.h
        PROTINFO # Protocol specific information for a link
        TXQLEN
        MAP
        WEIGHT
        OPERSTATE
        LINKMODE
        LINKINFO
        NET_NS_PID
        IFALIAS
        NUM_VF # Number of VFs if device is SR-IOV PF
        VFINFO_LIST
        STATS64
        VF_PORTS
        PORT_SELF
        AF_SPEC
        GROUP # Group the device belongs to
        NET_NS_FD
        EXT_MASK # Extended info mask, VFs, etc
        PROMISCUITY # Promiscuity count: > 0 means acts PROMISC
        NUM_TX_QUEUES
        NUM_RX_QUEUES
        CARRIER
        PHYS_PORT_ID
        CARRIER_CHANGES
        PHYS_SWITCH_ID
        LINK_NETNSID
        PHYS_PORT_NAME
        PROTO_DOWN
        GSO_MAX_SEGS
        GSO_MAX_SIZE
        PAD
        XDP
        EVENT
        NEW_NETNSID
        IF_NETNSID
        TARGET_NETNSID = IF_NETNSID # new alias
        CARRIER_UP_COUNT
        CARRIER_DOWN_COUNT
        NEW_IFINDEX
        MIN_MTU
        MAX_MTU
        PROP_LIST
        ALT_IFNAME # Alternative ifname
        PERM_ADDRESS
        PROTO_DOWN_REASON

        # device (sysfs) name as parent, used instead
        # of IFLA::LINK where there's no parent netdev
        PARENT_DEV_NAME
        PARENT_DEV_BUS_NAME
        GRO_MAX_SIZ
        TSO_MAX_SIZE
        TSO_MAX_SEGS
        ALLMULTI # Allmulti count: > 0 means acts ALLMULTI

        DEVLINK_PORT

        GSO_IPV4_MAX_SIZE
        GRO_IPV4_MAX_SIZE
        DPLL_PIN

        MAX
      end

      # Message event types
      # translated from /usr/include/linux/rtnetlink.h
      enum MessageType : UInt16
        NOOP = 0x1
        ERROR = 0x2
        DONE = 0x3
        OVERRUN = 0x4

        RTM_NEWLINK = 16
        RTM_BASE = 16 # mainly used for validation in kernel/C header-based APIs
        RTM_DELLINK
        RTM_GETLINK
        RTM_SETLINK

        RTM_NEWADDR = 20
        RTM_DELADDR
        RTM_GETADDR

        RTM_NEWROUTE = 24
        RTM_DELROUTE
        RTM_GETROUTE

        RTM_NEWNEIGH = 28
        RTM_DELNEIGH
        RTM_GETNEIGH

        RTM_NEWRULE = 32
        RTM_DELRULE
        RTM_GETRULE

        RTM_NEWQDISC = 36
        RTM_DELQDISC
        RTM_GETQDISC

        RTM_NEWTCLASS = 40
        RTM_DELTCLASS
        RTM_GETTCLASS

        RTM_NEWTFILTER = 44
        RTM_DELTFILTER
        RTM_GETTFILTER

        RTM_NEWACTION = 48
        RTM_DELACTION
        RTM_GETACTION

        RTM_NEWPREFIX = 52

        RTM_GETMULTICAST = 58

        RTM_GETANYCAST = 62

        RTM_NEWNEIGHTBL = 64
        RTM_GETNEIGHTBL = 66
        RTM_SETNEIGHTBL

        RTM_NEWNDUSEROPT = 68

        RTM_NEWADDRLABEL = 72
        RTM_DELADDRLABEL
        RTM_GETADDRLABEL

        RTM_GETDCB = 78
        RTM_SETDCB

        RTM_NEWNETCONF = 80
        RTM_DELNETCONF
        RTM_GETNETCONF = 82

        RTM_NEWMDB = 84
        RTM_DELMDB = 85
        RTM_GETMDB = 86

        RTM_NEWNSID = 88
        RTM_DELNSID = 89
        RTM_GETNSID = 90

        RTM_NEWSTATS = 92
        RTM_GETSTATS = 94

        RTM_NEWCACHEREPORT = 96

        RTM_NEWCHAIN = 100
        RTM_DELCHAIN
        RTM_GETCHAIN

        RTM_NEWNEXTHOP = 104
        RTM_DELNEXTHOP
        RTM_GETNEXTHOP

        RTM_NEWLINKPROP = 108
        RTM_DELLINKPROP
        RTM_GETLINKPROP

        RTM_NEWVLAN = 112
        RTM_DELVLAN
        RTM_GETVLAN

        RTM_NEWNEXTHOPBUCKET = 116
        RTM_DELNEXTHOPBUCKET
        RTM_GETNEXTHOPBUCKET
      end

      enum AttrType : LibC::UShort
        RTA_UNSPEC
        RTA_DST
        RTA_SRC
        RTA_IIF
        RTA_OIF
        RTA_GATEWAY
        RTA_PRIORITY
        RTA_PREFSRC
        RTA_METRICS
        RTA_MULTIPATH
        RTA_PROTOINFO # no longer used
        RTA_FLOW
        RTA_CACHEINFO
        RTA_SESSION # no longer used
        RTA_MP_ALGO # no longer used
        RTA_TABLE
        RTA_MARK
        RTA_MFC_STATS
        RTA_VIA
        RTA_NEWDST
        RTA_PREF
        RTA_ENCAP_TYPE
        RTA_ENCAP
        RTA_EXPIRES
        RTA_PAD
        RTA_UID
        RTA_TTL_PROPAGATE
        RTA_IP_PROTO
        RTA_SPORT
        RTA_DPORT
        RTA_NH_ID
        RTA_MAX
      end

      # rtnetlink_groups from /usr/include/linux/rtnetlink.h
      enum Groups
        LINK = 1
        IPV4_IFADDR = 0x10
        IPV4_ROUTE = 0x40
      end

      class RouteAttr
        NLA_F_NESTED = (1 << 15)
        NLA_F_NET_BYTEORDER = (1 << 14)
        NLA_TYPE_MASK = ~(NLA_F_NESTED | NLA_F_NET_BYTEORDER)

        getter length : LibC::UShort
        getter type : Netlink::Protocol::Route::IFLA
        getter is_nested : Bool
        getter is_network_byte_order : Bool
        getter data : Bytes

        def initialize(@length, @type, @is_nested, @is_network_byte_order, @data)
        end

        def self.from(attr_length, buffer : IO)
          pos = buffer.pos
          type = buffer.read_bytes(LibC::UShort)
          is_nested = type & NLA_F_NESTED == NLA_F_NESTED
          byte_order = type & NLA_F_NET_BYTEORDER == NLA_F_NET_BYTEORDER

          attr = new(
            attr_length,
            Netlink::Protocol::Route::IFLA.new(type & NLA_TYPE_MASK),
            is_nested,
            byte_order,
            buffer.to_slice[buffer.pos, attr_length - RATTR_SIZE]
          )
          # puts "offset before: #{pos}, after: #{buffer.pos + attr_length}, data size: #{attr_length}, data: #{attr.data}" if VERBOSE
          buffer.seek(nl_align(buffer.pos + attr_length - RATTR_SIZE))
          attr
        rescue err
          pp [buffer.size, buffer.pos, attr_length]
          raise err
        end
      end

      class MsgHeader < ::Netlink::MsgHeader
        getter type : MessageType
        def self.from!(buffer : IO)
          new(
            buffer.read_bytes(UInt32),
            MessageType.new(buffer.read_bytes(UInt16)),
            Netlink::Protocol::MessageFormatFlag.new(buffer.read_bytes(UInt16)),
            buffer.read_bytes(UInt32),
            buffer.read_bytes(UInt32)
          )
        end
      end

      # struct ifinfomsg from /usr/include/linux/rtnetlink.h
      class InterfaceInfoMessage
        getter family : LibC::Char
        @pad : LibC::Char
        getter type : LibC::UShort
        getter index : LibC::Int
        getter flags : LibC::UInt
        getter change : LibC::UInt

        def initialize(@family, @pad, @type, @index, @flags, @change)
        end

        def self.from!(buffer : IO)
          new(
            buffer.read_bytes(LibC::Char),
            buffer.read_bytes(LibC::Char),
            buffer.read_bytes(LibC::UShort),
            buffer.read_bytes(LibC::Int),
            buffer.read_bytes(LibC::UInt),
            buffer.read_bytes(LibC::UInt)
          )
        end
      end

      def self.socket : Netlink::Socket
        nl = Netlink::Socket.new(::Socket::NetlinkProtocol::ROUTE)
        groups = Groups::LINK | Groups::IPV4_IFADDR | Groups::IPV4_ROUTE
        nl.bind(groups.value)
        nl
      end

      def self.handle_message(response : IO)
        # return a struct/class instance or header/message type/list of RouteAttrs?
      end
    end
  end
end