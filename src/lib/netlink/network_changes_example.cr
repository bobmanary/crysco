# require "socket"
require "./socket_patch"
require "./socket"

# using netlink to create veth interface devices?
nl = Netlink::Socket.new(Socket::NetlinkProtocol::ROUTE)
groups = Netlink::Routes::LINK | Netlink::Routes::IPV4_IFADDR | Netlink::Routes::IPV4_ROUTE
nl.bind(groups.to_i)


msg = Netlink::MsgHeader.new(
  16u32, # size of the header struct, since we're not adding a payload
  Socket::NetlinkMsgType::NOOP,
  (Socket::NetlinkFlags::REQUEST | Socket::NetlinkFlags::ACK), # ACK will make the kernel always send a response back
  28u32, # arbitrary sequence number
  nl.pid
)

nl.sendmsg(msg.encode)

while true
  response = IO::Memory.new
  r = nl.receive()
  response.write(r[0])
  response.rewind

  header = Netlink::MsgHeader.from(response)

  case header.type
  when ::Socket::NetlinkMsgType::ERROR
    # should receive an error 0 back and a copy of the header we sent
    error = Netlink::MsgError.from(response)
    puts "error number: #{error.error}"
    pp error.header 
  when ::Socket::NetlinkMsgType::RTM_NEWADDR
    # todo: figure out how to parse the rest of the message?
    # (rtattr/ifla_*)
    i = 0
    r[0].each do |n|
      print n.to_s.rjust(4)
      i += 1
      if i == 4
        print '\n'
        i = 0
      end
    end
  end

  puts "type: #{header.type} (#{header.type.to_u16}), message length: #{header.length}, multi: #{header.flags & ::Socket::NetlinkFlags::MULTI}"
end