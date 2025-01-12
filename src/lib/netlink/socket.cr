# port of https://github.com/sdaubert/netlink/blob/f0b6db32cc54c90d7497710427b2c7cfdcc45018/lib/netlink/socket.rb#L12

require "socket"
require "./socket_patch"
require "./msg_header"
require "./msg_error"
require "./message"
require "./protocol"

module Netlink
  DEFAULT_BUFFER_SIZE = 32 * 1024

  class Socket
    @socket : ::Socket
    @family : ::Socket::NetlinkProtocol
    @@next_pid = 0u32
    getter pid : UInt32

    def self.sockaddr_nl(pid, groups)
      address = SocketPatch::SockaddrNl.new
      address.sa_family = ::Socket::AF_NETLINK
      address.nl_pad = 0u16
      address.nl_pid = pid
      address.nl_groups = groups
      address
    end

    def initialize(@family : ::Socket::NetlinkProtocol)
      @socket = ::Socket.netlink(@family)
      @pid = Socket.generate_pid
      @seqnum = 1
      @default_buffer_size = DEFAULT_BUFFER_SIZE
      @groups = 0
    end

    def self.generate_pid
      @@next_pid = Process.pid.to_u32 << 10 if @@next_pid == 0

      pid = @@next_pid
      @@next_pid += 1
      pid
    end

    def inspect(io : IO)
      io << "#<"
      io << self.class
      io << ":fd "
      io << @socket.fd
      io << ", AF_NETLINK, "
      io << @family
      io << ", "
      io << @pid
      io << ">"
      io
    end

    def bind(groups)
      @groups = groups
      sockaddr = self.class.sockaddr_nl(@pid, groups)
      @socket.bind(sockaddr)
    end

    def sendmsg(mesg, nlm_type = 0, nlm_flags = 0, flags = 0, dest_sockaddr : String? = nil)
      # nlmsg = create_or_update_nlmesg(mesg, nlm_type, nlm_flags)
      @socket.send(mesg)#, flags)
    end

    # Read a single raw response from the socket
    def receive() : {Bytes, ::Socket::NLAddress}
      bytes = Bytes.new(4096 * 4) # is this the right length?
      bytes_read, addr = @socket.receive(bytes)
      {bytes[0...bytes_read], addr.as(::Socket::NLAddress)}
    end

    def wait_for_multiple(message_types : Set(UInt16))
      count = message_types.size
      received_messages = Hash(UInt16, IO::Memory).new
      loop do
        response = receive()
        message = IO::Memory.new
        message.write(response[0])
        type = message.read_bytes(UInt16)
        if message_types.includes?(type) && !receved_messages.key?(type)
          received_messages[type] = message
          message.rewind
        end
        if received_messages.size == count
          break
        end
      end

      received_messages
    end

    # Send a message over the socket, then read a response repeatedly until
    # the header indicates that there are no more messages. A response will
    # be split into multiple netlink messages based on the header length
    # attribute. The split messages will be individually yielded to the block
    # as raw bytes.
    def request(request : Netlink::Message, &block : IO::Memory ->)
      sendmsg(request.serialize)

      loop do
        bytes, address = receive()
        position = 0u32
        while position < bytes.size
          length = bytes_to_u32(bytes[position, 4])
          yield(IO::Memory.new(bytes[position, length]))

          position = Protocol.nl_align(position + length)
        end
      end
    end

    private def seqnum
      current_seqnum = @seqnum
      @seqnum += 1
      current_seqnum
    end

    private def bytes_to_u32(bytes : Bytes) : UInt32
      raise "wtf" if bytes.size < 4
      IO::ByteFormat::SystemEndian.decode(UInt32, bytes)
    end
  end
end
