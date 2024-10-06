# require "socket"
require "./socket_patch"
require "./socket"

# using netlink to create veth interface devices?
nl = Netlink::Socket.new(Socket::NetlinkProtocol::ROUTE)
groups = Netlink::Routes::LINK | Netlink::Routes::IPV4_IFADDR | Netlink::Routes::IPV4_ROUTE
nl.bind(groups.to_i)

msg = Netlink::MsgHeader.new(16u32, Socket::NetlinkMsgType.new(0), (Socket::NetlinkFlags::REQUEST | Socket::NetlinkFlags::ACK), 28u32, nl.pid)

nl.sendmsg(msg.encode)

while true
  response = IO::Memory.new
  r = nl.receive()
  response.write(r[0])
  response.rewind

  # i = 0
  # r[0].each do |n|
  #   print n.to_s.rjust(4)
  #   i += 1
  #   if i == 4
  #     print '\n'
  #     i = 0
  #   end
  # end

  header = Netlink::MsgHeader.new(
    response.read_bytes(UInt32),
    ::Socket::NetlinkMsgType.new(response.read_bytes(UInt16)),
    ::Socket::NetlinkFlags.new(response.read_bytes(UInt16)),
    response.read_bytes(UInt32),
    response.read_bytes(UInt32)
  )

  puts "type: #{header.type} (#{header.type.to_u16}), message length: #{header.length}"
end