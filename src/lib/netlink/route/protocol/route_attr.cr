module Netlink
  module Route
    module Protocol
      RTATTR_SIZE = 4

      # T should be an enum representing the specific types for the family of attributes,
      # e.g. IFLA for link information or ???? for routes
      class RouteAttr(T)
        NLA_F_NESTED = (1 << 15)
        NLA_F_NET_BYTEORDER = (1 << 14)
        NLA_TYPE_MASK = ~(NLA_F_NESTED | NLA_F_NET_BYTEORDER)

        getter length : LibC::UShort
        getter type : T # IFLA
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
            T.new(type & NLA_TYPE_MASK),
            is_nested,
            byte_order,
            buffer.to_slice[buffer.pos, attr_length - RATTR_SIZE]
          )

          # seek past the data segment, if any
          if attr_length > RTATTR_SIZE
            buffer.seek(buffer.pos + nl_align(attr_length) - RATTR_SIZE)
          end

          attr
        rescue err
          pp [buffer.size, buffer.pos, attr_length]
          raise err
        end

        def self.ok?(buffer, attr_length)
          remaining = buffer.size - buffer.pos

          remaining >= RTATTR_SIZE &&
          attr_length >= RTATTR_SIZE &&
          attr_length <= remaining
        end
      end
    end
  end
end