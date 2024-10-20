# require "./socket_patch"
# require "socket"
require "./protocol"


module Netlink
  abstract class MsgHeader
    property length : UInt32
    # define with proper MessageType on subclasses:
    # getter type : Netlink::Protocol::____::MessageType
    getter flags : Netlink::Protocol::MessageFormatFlag
    getter seq : UInt32
    getter pid : UInt32

    # define with proper MessageType on subclasses:
    # def self.decode(buffer : IO)
    #   new(
    #     buffer.read_bytes(UInt32),
    #     Netlink::Protocol::____::MessageType.new(buffer.read_bytes(UInt16)),
    #     Netlink::Protocol::MessageFormatFlag.new(buffer.read_bytes(UInt16)),
    #     buffer.read_bytes(UInt32),
    #     buffer.read_bytes(UInt32)
    #   )
    # end

    def initialize(@length, @type, @flags, @seq, @pid)
    end

    def encode : IO::Memory
      msg = IO::Memory.new
      encode(msg)
      msg.rewind
    end

    def encode(io : IO::Memory)
      io.write_bytes(@length)
      io.write_bytes(@type.to_u16)
      io.write_bytes(@flags.to_u16)
      io.write_bytes(@seq)
      io.write_bytes(@pid)
      return
    end
  end
end
