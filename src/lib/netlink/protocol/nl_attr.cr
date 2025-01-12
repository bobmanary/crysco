require "../protocol"

module Netlink
  module Protocol
    ATTR_SIZE = 4

    # `type` should be an enum representing the specific types for the family of attributes,
    # e.g. IFLA for link information or ???? for routes
    class NlAttr
      NLA_F_NESTED = (1 << 15)
      NLA_F_NET_BYTEORDER = (1 << 14)
      NLA_TYPE_MASK = ~(NLA_F_NESTED | NLA_F_NET_BYTEORDER)

      getter length : UInt16
      getter type : UInt16
      getter is_nested : Bool
      getter is_network_byte_order : Bool
      getter data : Bytes

      def initialize(@length, @type, @is_nested, @is_network_byte_order, @data)
      end

      def self.from(attr_length, buffer : IO)
        pos = buffer.pos
        type = buffer.read_bytes(UInt16)
        is_nested = type & NLA_F_NESTED == NLA_F_NESTED
        byte_order = type & NLA_F_NET_BYTEORDER == NLA_F_NET_BYTEORDER

        attr = new(
          attr_length,
          (type & NLA_TYPE_MASK),
          is_nested,
          byte_order,
          buffer.to_slice[buffer.pos, attr_length - ATTR_SIZE]
        )

        # seek past the data segment, if any
        if attr_length > ATTR_SIZE
          buffer.seek(buffer.pos + Protocol.nl_align(attr_length) - ATTR_SIZE)
        end

        attr
      rescue err
        # Log.debug {"Failed to parse NlAttr"}
        pp [buffer.size, buffer.pos, attr_length]
        raise err
      end

      def self.ok?(buffer, attr_length)
        remaining = buffer.size - buffer.pos

        remaining >= ATTR_SIZE &&
        attr_length >= ATTR_SIZE &&
        attr_length <= remaining
      end
    end
  end
end
