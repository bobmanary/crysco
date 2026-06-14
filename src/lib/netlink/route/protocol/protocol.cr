require "../../msg_header"
require "../../socket"
require "./route_message"

module Netlink
  module Route
    module Protocol

      alias IFLA = InterfaceAttributes::IFLA # ???

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

      # net_device_flags (IFF_UP etc) from /usr/include/linux/if.h
      @[Flags]
      enum DeviceFlags : UInt32
        UP                          = 1<<0  # sysfs
        BROADCAST                   = 1<<1  # __volatile__
        DEBUG                       = 1<<2  # sysfs
        LOOPBACK                    = 1<<3  # __volatile__
        POINTOPOINT                 = 1<<4  # __volatile__
        NOTRAILERS                  = 1<<5  # sysfs
        RUNNING                     = 1<<6  # __volatile__
        NOARP                       = 1<<7  # sysfs
        PROMISC                     = 1<<8  # sysfs
        ALLMULTI                    = 1<<9  # sysfs
        MASTER                      = 1<<10 # __volatile__
        SLAVE                       = 1<<11 # __volatile__
        MULTICAST                   = 1<<12 # sysfs
        PORTSEL                     = 1<<13 # sysfs
        AUTOMEDIA                   = 1<<14 # sysfs
        DYNAMIC                     = 1<<15 # sysfs
        LOWER_UP                    = 1<<16 # __volatile__
        DORMANT                     = 1<<17 # __volatile__
        ECHO                        = 1<<18 # __volatile__
      end


      # rtnetlink_groups from /usr/include/linux/rtnetlink.h
      enum Groups
        LINK = 1
        IPV4_IFADDR = 0x10
        IPV4_ROUTE = 0x40
      end

      class MsgHeader < ::Netlink::MsgHeader
        # getter type : MessageType
        def self.from!(buffer : IO)
          new(
            buffer.read_bytes(UInt32), # length
            buffer.read_bytes(UInt16), # MessageType
            Netlink::Protocol::MessageFormatFlag.new(buffer.read_bytes(UInt16)),
            buffer.read_bytes(UInt32), # sequence
            buffer.read_bytes(UInt32) # pid
          )
        end

        def padded_size : UInt32
          16_u32
        end
      end

      # struct ifinfomsg from /usr/include/linux/rtnetlink.h
      class InterfaceInfoMessage < Netlink::Message::Segment
        getter family : LibC::Char
        @pad : LibC::Char
        getter type : LibC::UShort # /usr/include/linux/if_arp.h ARPHRD_* enum
        getter index : LibC::Int
        getter flags : DeviceFlags
        getter change : LibC::UInt
        getter attributes : InterfaceAttributes

        def padded_size : UInt32
          16_u32
        end

        def initialize(@family, @pad, @type, @index, flags, @change, @attributes)
          @flags = DeviceFlags.new(flags)
        end

        def initialize(@family, @pad, @type, @index, flags, @change)
          @flags = DeviceFlags.new(flags)
          @attributes = InterfaceAttributes.new(Hash(UInt16, Netlink::Protocol::NlAttr).new)
        end


        def self.from!(buffer : IO)
          new(
            buffer.read_bytes(LibC::Char),
            buffer.read_bytes(LibC::Char),
            buffer.read_bytes(LibC::UShort),
            buffer.read_bytes(LibC::Int),
            buffer.read_bytes(LibC::UInt),
            buffer.read_bytes(LibC::UInt),
            InterfaceAttributes.from!(buffer)
          )
        end

        def encode(io : IO)
          io.write_bytes(@family)
          io.write_bytes(@pad)
          io.write_bytes(@type)
          io.write_bytes(@index)
          io.write_bytes(@flags.value)
          io.write_bytes(@change)
          return
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
