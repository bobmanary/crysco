require "../../protocol/nl_attr"

module Netlink
  module Route
    module Protocol
      class RouteMessage
        abstract class RouteAttrParser
        end

        # NLA_U32 = ->(attr : NlAttr) { IO::ByteFormat::SystemEndian.decode(UInt32, attr.data }
        # NLA_U8 = ->(attr : NlAttr) { IO::ByteFormat::SystemEndian.decode(UInt8, attr.data }
        # NLA_MAC_ADDRESS = ->(attr : NlAttr) { attr.data.to_a }
        # NLA_STRING = ->(attr : NlAttr) { String.new(attr.data[0...(attr.length - 5)]) }

        class AttrTypeUnspec < RouteAttrParser
          # Found in the kernel API, but mainly used here for attributes
          # that have not been implemented yet
          def self.from
          end
        end

        class AttrTypeMacAddress < RouteAttrParser
          def self.from(attr : Netlink::Protocol::NlAttr) : Array(UInt8)
            attr.data.to_a
          end
        end

        class AttrTypeString < RouteAttrParser
          def self.from(attr : Netlink::Protocol::NlAttr) : String
            String.new(attr.data[0...(attr.length - 5)])
          end
        end

        class AttrTypeU32 < RouteAttrParser
          def self.from(attr : Netlink::Protocol::NlAttr) : UInt32
            IO::Memory.new(attr.data).read_bytes(UInt32)
          end
        end

        class AttrTypeU8 < RouteAttrParser
          def self.from(attr : Netlink::Protocol::NlAttr) : UInt8
            attr.data[0]
          end
        end

        # create an enum with the keys provided in 'fields', as well
        # as defining typed instance properties and a constructor to
        # assign them properly
        macro define_attribute_enum(enum_name, enum_type, fields)
          enum {{enum_name.id}} : {{enum_type.id}}
            {% for name, type in fields %}
              {{name}}
            {% end %}
          end

          # instance properties won't be defined for "unspecified" attributes
          {% for name, type in fields %}
            {% if type.id != "AttrTypeUnspec" %}
              property {{name.id.downcase}} : {{type.resolve.class.methods.find {|m| m.name.id == "from"}.return_type}}?
            {% end %}
          {% end %}

          def initialize(attributes : Hash(UInt16, Netlink::Protocol::NlAttr))
            {% for name, type in fields %}
              {% if type.id != "AttrTypeUnspec" %}
                if attributes.has_key?({{enum_name.id}}::{{name.id}}.value)
                  @{{name.id.downcase}} = {{type.id}}.from(attributes[{{enum_name.id}}::{{name.id}}.value])
                end
              {% end %}
            {% end %}
          end

          def self.from!(buffer : IO::Memory)
            attr_table = Hash(UInt16, Netlink::Protocol::NlAttr).new
            remaining = buffer.size
            loop do
              attr_len = buffer.read_bytes(LibC::UShort)
              break unless Netlink::Protocol::NlAttr.ok?(buffer, attr_len)
              attr = Netlink::Protocol::NlAttr.from(attr_len, buffer)
              if attr.type < {{enum_name.id}}::MAX.value
                attr_table[attr.type] = attr
              end
            end

            new(attr_table)
          end
        end
      end

      class InterfaceAttributes < RouteMessage
        @if_info : InterfaceInfoMessage?
        # Link data attribute identifiers
        # translated from /usr/include/linux/if_link.h
        define_attribute_enum(IFLA, UInt16, {
          UNSPEC => AttrTypeUnspec,
          ADDRESS => AttrTypeMacAddress,
          BROADCAST => AttrTypeMacAddress,
          IFNAME => AttrTypeString,
          MTU => AttrTypeU32,
          LINK => AttrTypeUnspec,
          QDISC => AttrTypeString,
          STATS => AttrTypeUnspec,
          COST => AttrTypeUnspec,
          PRIORITY => AttrTypeUnspec,
          MASTER => AttrTypeUnspec,
          WIRELESS => AttrTypeUnspec, # Wireless Extension event - see wireless.h
          PROTINFO => AttrTypeUnspec, # Protocol specific information for a link
          TXQLEN => AttrTypeU32,
          MAP => AttrTypeUnspec,
          WEIGHT => AttrTypeUnspec,
          OPERSTATE => AttrTypeU8,
          LINKMODE => AttrTypeU8,
          LINKINFO => AttrTypeUnspec,
          NET_NS_PID => AttrTypeUnspec,
          IFALIAS => AttrTypeString,
          NUM_VF => AttrTypeUnspec, # Number of VFs if device is SR-IOV PF
          VFINFO_LIST => AttrTypeUnspec,
          STATS64 => AttrTypeUnspec,
          VF_PORTS => AttrTypeUnspec,
          PORT_SELF => AttrTypeUnspec,
          AF_SPEC => AttrTypeUnspec,
          GROUP => AttrTypeU32, # Group the device belongs to
          NET_NS_FD => AttrTypeUnspec,                                             # this might be relevant
          EXT_MASK => AttrTypeUnspec, # Extended info mask, VFs, etc
          PROMISCUITY => AttrTypeU32, # Promiscuity count: > 0 means acts PROMISC
          NUM_TX_QUEUES => AttrTypeU32,
          NUM_RX_QUEUES => AttrTypeU32,
          CARRIER => AttrTypeUnspec,
          PHYS_PORT_ID => AttrTypeUnspec,
          CARRIER_CHANGES => AttrTypeUnspec,
          PHYS_SWITCH_ID => AttrTypeUnspec,
          LINK_NETNSID => AttrTypeUnspec,
          PHYS_PORT_NAME => AttrTypeUnspec,
          PROTO_DOWN => AttrTypeUnspec,
          GSO_MAX_SEGS => AttrTypeUnspec,
          GSO_MAX_SIZE => AttrTypeUnspec,
          PAD => AttrTypeUnspec,
          XDP => AttrTypeUnspec,
          EVENT => AttrTypeUnspec,
          NEW_NETNSID => AttrTypeUnspec,
          IF_NETNSID => AttrTypeUnspec, # aka TARGET_NETNSID
          CARRIER_UP_COUNT => AttrTypeUnspec,
          CARRIER_DOWN_COUNT => AttrTypeUnspec,
          NEW_IFINDEX => AttrTypeUnspec,
          MIN_MTU => AttrTypeU32,
          MAX_MTU => AttrTypeU32,
          PROP_LIST => AttrTypeUnspec,
          ALT_IFNAME => AttrTypeUnspec, # Alternative ifname
          PERM_ADDRESS => AttrTypeUnspec,
          PROTO_DOWN_REASON => AttrTypeUnspec,

          # device (sysfs) name as parent, used instead
          # of IFLA::LINK where there's no parent netdev
          PARENT_DEV_NAME => AttrTypeUnspec,
          PARENT_DEV_BUS_NAME => AttrTypeUnspec,
          GRO_MAX_SIZ => AttrTypeUnspec,
          TSO_MAX_SIZE => AttrTypeUnspec,
          TSO_MAX_SEGS => AttrTypeUnspec,
          ALLMULTI => AttrTypeUnspec, # Allmulti count: > 0 means acts ALLMULTI

          DEVLINK_PORT => AttrTypeUnspec,

          GSO_IPV4_MAX_SIZE => AttrTypeUnspec,
          GRO_IPV4_MAX_SIZE => AttrTypeUnspec,
          DPLL_PIN => AttrTypeUnspec,

          MAX => AttrTypeUnspec # for valid enum value checking only (e.g. number < IFLA::MAX)
        })
      end

    end
  end
end