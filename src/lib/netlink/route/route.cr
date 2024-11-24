require "./protocol/protocol"

module Netlink
  module Route
    def self.get_links : Array(Protocol::LinkMessage)
      rt_socket = Protocol.socket
      dump_request = Netlink::Message.new(Protocol::MsgHeader.new(
        16u32, # size of the header struct, since we're not adding a payload
        Netlink::Route::Protocol::MessageType::RTM_GETLINK,
        (Netlink::Protocol::MessageFormatFlag::REQUEST | Netlink::Protocol::MessageFormatFlag::DUMP), # ACK will make the kernel always send a response back
        28u32, # arbitrary sequence number
        rt_socket.pid
      ))

      links = [] of Protocol::LinkMessage
      # how are we parsing the messages here? inside .request or in this method?
      rt_socket.request(dump_request) do |response_bytes|
        nl_header = Protocol::MsgHeader.from!(response_bytes)
        if_info = Protocol::InterfaceInfoMessage.from!(response_bytes)
        links << Protocol::LinkMessage.from!(response_bytes)
      end

      links
    end
  end
end
