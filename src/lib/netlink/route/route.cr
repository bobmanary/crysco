require "./protocol/protocol"
require "../debug"

module Netlink
  module Route
    def self.get_network_interfaces : Array(Protocol::InterfaceInfoMessage)
      rt_socket = Protocol.socket
      dump_request = Netlink::Message.new(Protocol::MsgHeader.new(
        32u32, # size of the header struct, since we're not adding a payload
        Netlink::Route::Protocol::MessageType::RTM_GETLINK,
        (Netlink::Protocol::MessageFormatFlag::REQUEST | Netlink::Protocol::MessageFormatFlag::DUMP), # ACK will make the kernel always send a response back
        123u32, # arbitrary sequence number
        rt_socket.pid
      ))
      dump_request.add_segment(Protocol::InterfaceInfoMessage.new(
        0u8, 0, 0u16, 0, 0u32, 0xFFFFFFFFu32
      ))

      links = [] of Protocol::InterfaceInfoMessage
      # how are we parsing the messages here? inside .request or in this method?
      rt_socket.request(dump_request) do |response_bytes|
        # Netlink::Debug.print_bytes(response_bytes)
        nl_header = Protocol::MsgHeader.from!(response_bytes)

        break if nl_header.done?

        links << Protocol::InterfaceInfoMessage.from!(response_bytes)
      end

      links
    end
  end
end
