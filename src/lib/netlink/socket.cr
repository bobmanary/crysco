# port of https://github.com/sdaubert/netlink/blob/f0b6db32cc54c90d7497710427b2c7cfdcc45018/lib/netlink/socket.rb#L12

require "socket"
require "./socket_patch"
require "./msg_header"
require "./msg_error"

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
      puts "socket type: #{@socket.type}"
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

    def receive()
      bytes = Bytes.new(4096)
      bytes_read, addr = @socket.receive(bytes)
      {bytes[0...bytes_read], addr}
    end

    private def create_or_update_nlmesg(message : String)
      header = NlHeader.new(type: type, flags: flags, seq: seqnum, pid: @pid)
      NlMessage.new(message, header)
    end

    private def seqnum
      current_seqnum = @seqnum
      @seqnum += 1
      current_seqnum
    end
  end
end
