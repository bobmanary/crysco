# port of https://github.com/sdaubert/netlink/blob/f0b6db32cc54c90d7497710427b2c7cfdcc45018/lib/netlink/socket.rb#L12

require "./socket_patch"

module Netlink
  DEFAULT_BUFFER_SIZE = 32 * 1024

  class Socket
    @socket : ::Socket
    @family : ::Socket::NetlinkProtocol
    @@next_pid = -1
    @pid : Int32

    def self.sockaddr_nl(pid, groups)
      io = IO::Memory.new
      io.write_bytes(::Socket::AF_NETLINK)
      io.write_bytes(0u16)
      io.write_bytes(pid)
      io.write_bytes(groups)
      io.rewind.to_slice
    end

    def initialize(@family : ::Socket::NetlinkProtocol)
      @socket = ::Socket.netlink(@family)
      @pid = Socket.generate_pid
      @seqnum = 1
      @default_buffer_size = DEFAULT_BUFFER_SIZE
      @groups = 0
    end

    def addr
      {"AF_NETLINK", @pid, @groups}
    end

    def self.generate_pid
      @@next_pid = Process.pid.to_i << 10 if @@next_pid ==-1

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
      # TODO
      @socket.bind(sockaddr)
    end
  
    def sendmsg(mesg, nlm_type = 0, nlm_flags = 0, flags = 0, dest_sockaddr : String? = nil)
      nlmsg = create_or_update_nlmesg(mesg, nlm_type, nlm_flags)
      @socket.send(nlmsg.encode, flags)
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

# using netlink to create veth interface devices?
nl = Netlink::Socket.new(Socket::NetlinkProtocol::ROUTE)
nl.bind(0) # todo: hack up Socket#bind
