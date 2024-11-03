module Netlink
  module Protocol
    module Route
      class RouteMessage
        abstract class RouteAttrParser
        end

        class Unspec < RouteAttrParser
          # Found in the kernel API, but mainly used here for attributes
          # that have not been implemented yet
          def self.from
          end
        end

        class MacAddress < RouteAttrParser
          def self.from(attr : RouteAttr) : Array(UInt8)
            attr.data.to_a
          end
        end

        class IflaString < RouteAttrParser
          def self.from(attr : RouteAttr) : String
            String.new(attr.data[0...(attr.length - 5)])
          end
        end

        class IflaU32 < RouteAttrParser
          def self.from(attr : RouteAttr) : UInt32
            IO::Memory.new(attr.data).read_bytes(UInt32)
          end
        end

        class IflaU8 < RouteAttrParser
          def self.from(attr : RouteAttr) : UInt8
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
            {% if type.id != "Unspec" %}
              property {{name.id.downcase}} : {{type.resolve.class.methods.find {|m| m.name.id == "from"}.return_type}}?
            {% end %}
          {% end %}

          def initialize(attributes : Hash({{enum_name.id}}, Netlink::Protocol::Route::RouteAttr))
            {% for name, type in fields %}
              {% if type.id != "Unspec" %}
                if attributes.has_key?({{enum_name.id}}::{{name.id}})
                  @{{name.id.downcase}} = {{type.id}}.from(attributes[{{enum_name.id}}::{{name.id}}])
                end
              {% end %}
            {% end %}
          end
        end
      end

      class LinkMessage < RouteMessage
        # Link data attribute identifiers
        # translated from /usr/include/linux/if_link.h
        define_attribute_enum(IFLA, UInt16, {
          UNSPEC => Unspec,
          ADDRESS => MacAddress,
          BROADCAST => MacAddress,
          IFNAME => IflaString,
          MTU => IflaU32,
          LINK => Unspec,
          QDISC => IflaString,
          STATS => Unspec,
          COST => Unspec,
          PRIORITY => Unspec,
          MASTER => Unspec,
          WIRELESS => Unspec, # Wireless Extension event - see wireless.h
          PROTINFO => Unspec, # Protocol specific information for a link
          TXQLEN => IflaU32,
          MAP => Unspec,
          WEIGHT => Unspec,
          OPERSTATE => IflaU8,
          LINKMODE => IflaU8,
          LINKINFO => Unspec,
          NET_NS_PID => Unspec,
          IFALIAS => IflaString,
          NUM_VF => Unspec, # Number of VFs if device is SR-IOV PF
          VFINFO_LIST => Unspec,
          STATS64 => Unspec,
          VF_PORTS => Unspec,
          PORT_SELF => Unspec,
          AF_SPEC => Unspec,
          GROUP => IflaU32, # Group the device belongs to
          NET_NS_FD => Unspec,                                             # this might be relevant
          EXT_MASK => Unspec, # Extended info mask, VFs, etc
          PROMISCUITY => IflaU32, # Promiscuity count: > 0 means acts PROMISC
          NUM_TX_QUEUES => IflaU32,
          NUM_RX_QUEUES => IflaU32,
          CARRIER => Unspec,
          PHYS_PORT_ID => Unspec,
          CARRIER_CHANGES => Unspec,
          PHYS_SWITCH_ID => Unspec,
          LINK_NETNSID => Unspec,
          PHYS_PORT_NAME => Unspec,
          PROTO_DOWN => Unspec,
          GSO_MAX_SEGS => Unspec,
          GSO_MAX_SIZE => Unspec,
          PAD => Unspec,
          XDP => Unspec,
          EVENT => Unspec,
          NEW_NETNSID => Unspec,
          IF_NETNSID => Unspec, # aka TARGET_NETNSID
          CARRIER_UP_COUNT => Unspec,
          CARRIER_DOWN_COUNT => Unspec,
          NEW_IFINDEX => Unspec,
          MIN_MTU => IflaU32,
          MAX_MTU => IflaU32,
          PROP_LIST => Unspec,
          ALT_IFNAME => Unspec, # Alternative ifname
          PERM_ADDRESS => Unspec,
          PROTO_DOWN_REASON => Unspec,

          # device (sysfs) name as parent, used instead
          # of IFLA::LINK where there's no parent netdev
          PARENT_DEV_NAME => Unspec,
          PARENT_DEV_BUS_NAME => Unspec,
          GRO_MAX_SIZ => Unspec,
          TSO_MAX_SIZE => Unspec,
          TSO_MAX_SEGS => Unspec,
          ALLMULTI => Unspec, # Allmulti count: > 0 means acts ALLMULTI

          DEVLINK_PORT => Unspec,

          GSO_IPV4_MAX_SIZE => Unspec,
          GRO_IPV4_MAX_SIZE => Unspec,
          DPLL_PIN => Unspec,

          MAX => Unspec # for valid enum value checking only (e.g. number < IFLA::MAX)
        })
      end

    end
  end
end