require "./socket_patch"
require "socket"

module Netlink
  class MsgHeader
    property length : UInt32
    getter type : ::Socket::NetlinkMsgType
    getter flags : ::Socket::NetlinkFlags
    getter seq : UInt32
    getter pid : UInt32

    def initialize(@length, @type, @flags, @seq, @pid)
    end

    def encode : IO::Memory
      msg = IO::Memory.new
      msg.write_bytes(@length)
      msg.write_bytes(@type.to_u16)
      msg.write_bytes(@flags.to_u16)
      msg.write_bytes(@seq)
      msg.write_bytes(@pid)
      msg.rewind
    end
  end
end
