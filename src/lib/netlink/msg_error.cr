require "./msg_header"

module Netlink
  class MsgError
    getter error : Int32
    getter header : MsgHeader

    def self.from(buffer : IO::Memory)
      new(
        buffer.read_bytes(Int32),
        MsgHeader.from(buffer)
      )
    end

    def initialize(@error, @header)

    end
  end
end
