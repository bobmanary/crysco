# require "socket"
require "./socket_patch"
require "./socket"

IFLA_MAX = 58
RATTR_SIZE = 4
VERBOSE = false

enum IFLA : UInt16
	UNSPEC
	ADDRESS
	BROADCAST
	IFNAME
	MTU
	LINK
	QDISC
	STATS
	COST
	PRIORITY
	MASTER
	WIRELESS # Wireless Extension event - see wireless.h
	PROTINFO # Protocol specific information for a link
	TXQLEN
	MAP
	WEIGHT
	OPERSTATE
	LINKMODE
	LINKINFO
	NET_NS_PID
	IFALIAS
	NUM_VF # Number of VFs if device is SR-IOV PF
	VFINFO_LIST
	STATS64
	VF_PORTS
	PORT_SELF
	AF_SPEC
	GROUP # Group the device belongs to
	NET_NS_FD
	EXT_MASK # Extended info mask, VFs, etc
	PROMISCUITY # Promiscuity count: > 0 means acts PROMISC
	NUM_TX_QUEUES
	NUM_RX_QUEUES
	CARRIER
	PHYS_PORT_ID
	CARRIER_CHANGES
	PHYS_SWITCH_ID
	LINK_NETNSID
	PHYS_PORT_NAME
	PROTO_DOWN
	GSO_MAX_SEGS
	GSO_MAX_SIZE
	PAD
	XDP
	EVENT
	NEW_NETNSID
	IF_NETNSID
	TARGET_NETNSID = IF_NETNSID # new alias
	CARRIER_UP_COUNT
	CARRIER_DOWN_COUNT
	NEW_IFINDEX
	MIN_MTU
	MAX_MTU
	PROP_LIST
	ALT_IFNAME # Alternative ifname
	PERM_ADDRESS
	PROTO_DOWN_REASON

	# device (sysfs) name as parent, used instead
	# of IFLA::LINK where there's no parent netdev
	PARENT_DEV_NAME
	PARENT_DEV_BUS_NAME

	MAX
end


# using netlink to create veth interface devices?
nl = Netlink::Socket.new(Socket::NetlinkProtocol::ROUTE)
groups = Netlink::Routes::LINK | Netlink::Routes::IPV4_IFADDR | Netlink::Routes::IPV4_ROUTE
nl.bind(groups.to_i)

class IfInfoMsg
  getter family : LibC::Char
  @pad : LibC::Char
  getter type : LibC::UShort
  getter index : LibC::Int
  getter flags : LibC::UInt
  getter change : LibC::UInt

  def initialize(@family, @pad, @type, @index, @flags, @change)
  end

  def self.from(buffer : IO)
    new(
      buffer.read_bytes(LibC::Char),
      buffer.read_bytes(LibC::Char),
      buffer.read_bytes(LibC::UShort),
      buffer.read_bytes(LibC::Int),
      buffer.read_bytes(LibC::UInt),
      buffer.read_bytes(LibC::UInt)
    )
  end
end

class RouteAttr
  getter length : LibC::UShort
  getter type : LibC::UShort
  getter data : Bytes

  def initialize(@length, @type, @data)
  end

  def self.from(attr_length, buffer : IO)
    pos = buffer.pos
    attr = new(
      attr_length,
      buffer.read_bytes(LibC::UShort),
      buffer.to_slice[buffer.pos, attr_length - RATTR_SIZE]
    )
    puts "offset before: #{pos}, after: #{buffer.pos + attr_length}, data size: #{attr_length}, data: #{attr.data}" if VERBOSE
    buffer.seek(nl_align(buffer.pos + attr_length - RATTR_SIZE))
    attr
  rescue err
    pp [buffer.size, buffer.pos, attr_length]
    raise err
  end
end

def nl_align(pos)
  pos + 3 & ~3
end

def rta_ok(attr_length, msg_length)
  msg_length >= RATTR_SIZE &&
  attr_length >= RATTR_SIZE &&
  attr_length <= msg_length
end


def parse_route_attrs(buffer, enum_max) : Array(RouteAttr?)
  attr_table = Array(RouteAttr?).new(enum_max, nil)
  remaining = buffer.size# - buffer.pos
  i = 0
  loop do
    puts "parsing rattr #{i} at #{buffer.pos}/#{remaining}" if VERBOSE
    i += 1
    break if buffer.size - buffer.pos < 4
    attr_len = buffer.read_bytes(LibC::UShort)
    remaining -= nl_align(attr_len)
    attr = RouteAttr.from(attr_len, buffer)
    puts "rattr {\n  len #{attr.length}\n  type #{attr.type} (#{attr.type.to_i})\n}" if VERBOSE
    unless rta_ok(attr_len, remaining)
      puts "rta not ok: #{attr_len}, #{remaining}, #{buffer.pos}" if VERBOSE
      next
    end

    if attr.type < enum_max
      attr_table[attr.type] = attr
    end
  end
  attr_table
end


msg = Netlink::MsgHeader.new(
  16u32, # size of the header struct, since we're not adding a payload
  Socket::NetlinkMsgType::NOOP,
  (Socket::NetlinkFlags::REQUEST | Socket::NetlinkFlags::ACK), # ACK will make the kernel always send a response back
  28u32, # arbitrary sequence number
  nl.pid
)

nl.sendmsg(msg.encode)

received_count = 0

def handle_message(response : IO)
  r = {response.to_slice}
  puts "position before parsing header: #{response.pos}" if VERBOSE
  header = Netlink::MsgHeader.from(response)
  if header.length != response.size
    puts "oh no! message size mismatch: #{header.length} != #{response.size}"
    exit 1
  end

  puts "\n\n---message type: #{header.type.to_s} (##{header.type.to_i})" if VERBOSE
  # path = Path["./netlink-samples", "#{received_count.to_s.rjust(3, '0')}-#{header.type.to_s}"]
  # File.write(path, r[0])
  # received_count += 1
  # pp header
  print_bytes(r[0]) if VERBOSE

  case header.type
  when ::Socket::NetlinkMsgType::ERROR
    # should receive an error 0 back and a copy of the header we sent
    error = Netlink::MsgError.from(response)
    puts "error number: #{error.error}" if VERBOSE
    pp error.header if VERBOSE
  # when ::Socket::NetlinkMsgType::RTM_NEWADDR
  when ::Socket::NetlinkMsgType::RTM_NEWROUTE
  when ::Socket::NetlinkMsgType::RTM_DELROUTE
  when ::Socket::NetlinkMsgType::RTM_DELLINK
    puts "position before parsing IfInfoMsg: #{response.pos}" if VERBOSE
    data = IfInfoMsg.from(response)
    pp data if VERBOSE
    while response.pos < response.size
      table = parse_route_attrs(response, IFLA::MAX.to_i)
      attr = table[IFLA::IFNAME.to_i]
      if attr.is_a?(RouteAttr)
        ifname = String.new(attr.data)
        puts "Network interface #{ifname} was removed"
      end
      # begin
      #   rattr_len = response.read_bytes(UInt16)
      #   rattr_type = IFLA.new(response.read_bytes(UInt16))
      # rescue
      #   puts "error reading rattr length or type"
      #   exit 1
      # end
      # if rattr_type >= IFLA::MAX
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

      # puts "rattr {\n  len #{rattr_len}\n  type #{rattr_type} (#{rattr_type.to_i})\n  data #{rattr_data}\n}"
    end
    # puts "position before parsing attrs: #{response.pos}"

    # attrs = parse_route_attrs(response, IFLA::MAX)

    # pp attrs.select {|attr| !attr.nil? }
    # todo: figure out how to parse the rest of the message?
    # (rtattr/ifla_*)
    
  end



  puts "type: #{header.type} (#{header.type.to_u16}), message length: #{header.length}, multi: #{header.flags & ::Socket::NetlinkFlags::MULTI}"
end

def print_bytes(slice)
  i = 0
  j = 0
  slice.each do |n|
    if i == 0
      print j.to_s.rjust(4)
      print "  "
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
