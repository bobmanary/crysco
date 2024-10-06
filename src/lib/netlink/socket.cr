# port of https://github.com/sdaubert/netlink/blob/f0b6db32cc54c90d7497710427b2c7cfdcc45018/lib/netlink/socket.rb#L12

require "./socket_patch"

module Netlink
  DEFAULT_BUFFER_SIZE = 32 * 1024

  enum Routes
    LINK = 1
    IPV4_IFADDR = 0x10
    IPV4_ROUTE = 0x40
  end

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

    def addr
      {"AF_NETLINK", @pid, @groups}
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
      # TODO
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

class Header
  property length : UInt32
  getter type : Socket::NetlinkMsgType
  getter flags : Socket::NetlinkFlags
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
# using netlink to create veth interface devices?
nl = Netlink::Socket.new(Socket::NetlinkProtocol::ROUTE)
groups = Netlink::Routes::LINK | Netlink::Routes::IPV4_IFADDR | Netlink::Routes::IPV4_ROUTE
nl.bind(groups.to_i)

msg = Header.new(16u32, Socket::NetlinkMsgType.new(0), (Socket::NetlinkFlags::REQUEST | Socket::NetlinkFlags::ACK), 28u32, nl.pid)
# header
# msg.write_bytes(0u32) # size, update later
# msg.write_bytes(0u16) # type
# msg.write_bytes((Socket::NetlinkFlags::REQUEST | Socket::NetlinkFlags::ACK).to_u16) # flags
# msg.write_bytes(0u32) # sequence number
# msg.write_bytes(nl.pid) # process id

# # message
# msg.write_bytes(0x01)
# msg.write_bytes(0x02)
# msg.write_bytes(0x03)
# msg.write_bytes(0x04)

# update size
# msg.rewind
# # puts msg.to_slice
# msg.write_bytes(msg.size)
# # puts msg.to_slice
# puts msg.size


nl.sendmsg(msg.encode)
# puts msg.to_slice
# response = nl.receive
# puts "response: #{typeof(response[0])} #{response[0]} #{response[1]} #{response[0].size}"

response = IO::Memory.new
r = nl.receive()
# pp r
response.write(r[0])
response.rewind

i = 0
r[0].each do |n|
  print n.to_s.rjust(4)
  i += 1
  if i == 4
    print '\n'
    i = 0
  end
end

header = Header.new(
  response.read_bytes(UInt32),
  Socket::NetlinkMsgType.new(response.read_bytes(UInt16)),
  Socket::NetlinkFlags.new(response.read_bytes(UInt16)),
  response.read_bytes(UInt32),
  response.read_bytes(UInt32)
)

pp header
puts "OH: #{header.type.to_u16}"
puts "NO: #{header.flags.to_u16}"
pp response.buffer.value