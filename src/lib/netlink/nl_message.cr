module Netlink
  class Message
    enum Type : UInt16

    end

    getter size : UInt32
    getter type : Type

    def self.from(bytes : Bytes)

    end
  end
end
