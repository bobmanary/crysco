# require "socket"
require "./socket_patch"
require "./socket"
require "./protocol"
require "./protocol/route"

RATTR_SIZE = 4
VERBOSE = false



# using netlink to create veth interface devices?
# nl = Netlink::Socket.new(Socket::NetlinkProtocol::ROUTE)
# groups = Netlink::Routes::LINK | Netlink::Routes::IPV4_IFADDR | Netlink::Routes::IPV4_ROUTE
# nl.bind(groups.value)
nl = Netlink::Protocol::Route.socket

def nl_align(pos)
  pos + 3 & ~3
end

def rta_ok(attr_length, msg_length)
  msg_length >= RATTR_SIZE &&
  attr_length >= RATTR_SIZE &&
  attr_length <= msg_length
end


def parse_route_attrs(buffer, enum_max) : Hash(Netlink::Protocol::Route::IFLA, Netlink::Protocol::Route::RouteAttr)
  attr_table = Hash(Netlink::Protocol::Route::IFLA, Netlink::Protocol::Route::RouteAttr).new
  remaining = buffer.size# - buffer.pos
  i = 0
  loop do
    puts "parsing rattr #{i} at #{buffer.pos}/#{remaining}" if VERBOSE
    i += 1
    break if buffer.size - buffer.pos < 4
    attr_len = buffer.read_bytes(LibC::UShort)
    remaining -= nl_align(attr_len)
    attr = Netlink::Protocol::Route::RouteAttr.from(attr_len, buffer)
    puts "rattr {\n  len #{attr.length}\n  type IFLA::#{attr.type} (#{attr.type.value})\n  is_nested #{attr.is_nested}\n}" if VERBOSE
    unless rta_ok(attr_len, remaining)
      puts "RTATTR NOT OK: attr_len: #{attr_len}, remain: #{remaining}, buffer: #{buffer.pos}/#{buffer.size}, data size: #{attr.data.size}" if VERBOSE
      next
    end

    if attr.type.value < enum_max
      attr_table[attr.type] = attr
    end
  end
  attr_table
end

msg = Netlink::Protocol::Route::MsgHeader.new(
  16u32, # size of the header struct, since we're not adding a payload
  Netlink::Protocol::Route::MessageType::NOOP,
  (Netlink::Protocol::MessageFormatFlag::REQUEST | Netlink::Protocol::MessageFormatFlag::ACK), # ACK will make the kernel always send a response back
  28u32, # arbitrary sequence number
  nl.pid
)

nl.sendmsg(msg.encode)

received_count = 0

def handle_message(response : IO)
  r = {response.to_slice}
  puts "position before parsing header: #{response.pos}" if VERBOSE
  header = Netlink::Protocol::Route::MsgHeader.from!(response)
  if header.length != response.size
    puts "oh no! message size mismatch: #{header.length} != #{response.size}"
    exit 1
  end

  puts "\n\n---message type: #{header.type.to_s} (##{header.type.value})" if VERBOSE
  # path = Path["./netlink-samples", "#{received_count.to_s.rjust(3, '0')}-#{header.type.to_s}"]
  # File.write(path, r[0])
  # received_count += 1
  # pp header
  print_bytes(r[0]) if VERBOSE

  case header.type
  when Netlink::Protocol::Route::MessageType::ERROR
    # should receive an error 0 back and a copy of the header we sent
    error_code = response.read_bytes(Int32)
    puts "error number: #{error_code}" if VERBOSE
    # error = Netlink::MsgError.from(response)
    # puts "error number: #{error.error}" if VERBOSE
    # pp error.header if VERBOSE
  # when Netlink::Protocol::Route::MessageType::RTM_NEWADDR
  # when Netlink::Protocol::Route::MessageType::RTM_NEWROUTE
  # when Netlink::Protocol::Route::MessageType::RTM_DELROUTE
  when Netlink::Protocol::Route::MessageType::RTM_NEWLINK
    data = Netlink::Protocol::Route::InterfaceInfoMessage.from!(response)
    pp data if VERBOSE
    while response.pos < response.size
      table = parse_route_attrs(response, Netlink::Protocol::Route::IFLA::MAX.value)
      if table.has_key?(Netlink::Protocol::Route::IFLA::IFNAME)
        attr = table[Netlink::Protocol::Route::IFLA::IFNAME]
        ifname = String.new(attr.data)
        puts "Network interface #{ifname} was added"
      end
    end
  when Netlink::Protocol::Route::MessageType::RTM_DELLINK
    data = Netlink::Protocol::Route::InterfaceInfoMessage.from!(response)
    pp data if VERBOSE
    while response.pos < response.size
      table = parse_route_attrs(response, Netlink::Protocol::Route::IFLA::MAX.value)
      if table.has_key?(Netlink::Protocol::Route::IFLA::IFNAME)
        attr = table[Netlink::Protocol::Route::IFLA::IFNAME]
        ifname = String.new(attr.data)
        puts "Network interface #{ifname} was removed"
      end
      # begin
      #   rattr_len = response.read_bytes(UInt16)
      #   rattr_type = Netlink::Protocol::Route::IFLA.new(response.read_bytes(UInt16))
      # rescue
      #   puts "error reading rattr length or type"
      #   exit 1
      # end
      # if rattr_type >= Netlink::Protocol::Route::IFLA::MAX
      #   puts "rta_type > max, skipping"
      #   response.pos = nl_align(response.pos + rattr_len - RATTR_SIZE)
      #   next
      # end
      # begin
      #   rattr_data = response.to_slice[response.pos + RATTR_SIZE, rattr_len - RATTR_SIZE]
      #   puts "size: #{rattr_data.size}"
      # rescue err
      #   puts "error reading rattr data at #{response.pos} + #{rattr_len}"
      #   puts err
      #   exit 1
      # end
      # begin
      #   response.pos = nl_align(response.pos + rattr_len - RATTR_SIZE)
      # rescue err
      #   puts "error aligning buffer pos to #{response.pos + rattr_len}"
      #   puts err
      #   exit 1
      # end

      # puts "rattr {\n  len #{rattr_len}\n  type #{rattr_type} (#{rattr_type.value})\n  data #{rattr_data}\n}"
    end
    # puts "position before parsing attrs: #{response.pos}"

    # attrs = parse_route_attrs(response, IFLA::MAX)

    # pp attrs.select {|attr| !attr.nil? }
    # todo: figure out how to parse the rest of the message?
    # (rtattr/ifla_*)
  else
    puts "message type: #{header.type.to_s}"
  end



  puts "type: #{header.type} (#{header.type.to_u16}), message length: #{header.length}, multi: #{header.flags & ::Netlink::Protocol::MessageFormatFlag::MULTI}"
end

def print_bytes(slice)
  i = 0
  j = 0
  slice.each do |n|
    if i == 0
      print j.to_s.rjust(4)
      print "    "
    end
    print n.to_s.rjust(4)
    if n >= 32 && n <= 126
      print " #{String.new(pointerof(n), 1)}"
    else
      print " ."
    end
    i += 1
    if i == 4
      print '\n'
      i = 0
    else
      print ' '
    end
    j += 1
  end
end

# handle from actual socket
while true
  response = IO::Memory.new
  r = nl.receive()

  response.write(r[0])
  response.rewind
  handle_message(response)
end

# handle saved messages
# Dir["./netlink-samples/*"].each do |filename|
#   puts filename
#   File.open(filename) do |file|
#     slice = Bytes.new(file.size)
#     file.read_fully(slice)
#     response = IO::Memory.new
#     response.write(slice)
#     response.rewind
#     handle_message(response)
#   end
# end
