module Netlink
  module Protocol

    # Message type flags shared across Netlink families
    # Translated from /usr/include/linux/netlink.h
    # (prefixed with NLM_F_ in the C header)
    # (should maybe be constants instead of an enum)
    enum MessageFormatFlag : UInt16
      REQUEST = 0x1
      MULTI = 0x2
      ACK = 0x4
      ECHO = 0x8
      DUMP_INTR = 0x10
      DUMP_FILTERED = 0x20

      # Modifiers to GET request
      ROOT = 0x100
      MATCH = 0x200
      ATOMIC = 0x400
      F_DUMP = 0x100 | 0x200

      # Modifiers to DELETE request
      NONREC = 0x100
      BULK = 0x200

      # Modifiers for ACK message
      CAPPED = 0x100
      ACK_TLVS = 0x200
    end
  end
end
