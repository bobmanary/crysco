require "./protocol/protocol"

module Netlink
  module Route
    def self.get_links : Array(Protocol::RouteMessage)
      socket = Protocol.socket
      dump_request = Netlink::Message.new
      dump_request.add_segment(Protocol::MsgHeader.new(
        16u32, # size of the header struct, since we're not adding a payload
        Netlink::Route::Protocol::MessageType::RTM_GETLINK,
        (Netlink::Protocol::MessageFormatFlag::REQUEST | Netlink::Protocol::MessageFormatFlag::DUMP), # ACK will make the kernel always send a response back
        28u32, # arbitrary sequence number
        socket.pid
      ))

      links = [] of Protocol::RouteMessage
      # how are we parsing the messages here? inside .request or in this method?
      socket.request(dump_request) do |response_bytes|
        links << Protocol::RouteMessage.from(response_bytes)
      end

      links
    end
  end
end
