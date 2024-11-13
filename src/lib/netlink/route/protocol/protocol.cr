require "../../msg_header"
require "../../socket"
require "./route_message"

module Netlink
  module Route
    module Protocol

      alias IFLA = LinkMessage::IFLA # ???

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

      RATTR_SIZE = 4
      class RouteAttr
        NLA_F_NESTED = (1 << 15)
        NLA_F_NET_BYTEORDER = (1 << 14)
        NLA_TYPE_MASK = ~(NLA_F_NESTED | NLA_F_NET_BYTEORDER)

        getter length : LibC::UShort
        getter type : IFLA
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

          # puts "wat: #{[attr_length, buffer.size, buffer.pos]}"
          # puts "wat2 #{buffer.pos} #{attr_length}, #{RATTR_SIZE}"
          attr = new(
            attr_length,
            Netlink::Protocol::Route::IFLA.new(type & NLA_TYPE_MASK),
            is_nested,
            byte_order,
            buffer.to_slice[buffer.pos, attr_length - RATTR_SIZE]
          )

          # seek past the data segment, if any
          if attr_length > RATTR_SIZE
            buffer.seek(buffer.pos + nl_align(attr_length) - RATTR_SIZE)
          end

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

        def padded_size : UInt32
          16_u32
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

        def encode(buffer : IO)
          buffer.write_bytes(@family)
          buffer.write_bytes(@type)
          buffer.write_bytes(@index)
          buffer.write_bytes(@flags)
          buffer.write_bytes(@change)
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