# output something similar to running iproute2's `ip link` command,
# using the library's high level API.

require "../socket_patch"
require "../socket"
require "../route/protocol/protocol"
require "../route/route"
alias DeviceFlags = Netlink::Route::Protocol::DeviceFlags

interfaces = Netlink::Route.get_network_interfaces
oper_states = ["UNKNOWN", "NOTPRESENT", "DOWN", "LOWERLAYERDOWN", "TESTING", "DORMANT", "UP"]
link_modes = ["DEFAULT", "DORMANT"]

interfaces.each do |interface|
  attrs = interface.attributes

  flags = interface.flags
  flag_strings = [] of String
  flag_strings << "NO-CARRIER" if flags.includes?(DeviceFlags::UP) && !flags.includes?(DeviceFlags::RUNNING)
  flags.each do |f|
    flag_strings << f.to_s unless f == DeviceFlags::RUNNING
  end

  # puts interface.flags
  txqlen = attrs.txqlen
  qlen_str = (!txqlen.nil? && txqlen > 0) ? " qlen #{attrs.txqlen}" : ""

  group = attrs.group
  group_str = group.nil? || group == 0u32 ? "default" : group.to_s

  oper_state = attrs.operstate
  state_str = if oper_state.nil?
    ""
  else
    " state #{oper_state < oper_states.size ? oper_states[oper_state] : oper_state}"
  end

  linkmode = attrs.linkmode
  mode_str = if linkmode.nil?
    ""
  else
    " mode #{linkmode < link_modes.size ? link_modes[linkmode] : linkmode}"
  end

  puts "#{interface.index}: #{attrs.ifname}: <#{flag_strings.join(',')}> mtu #{attrs.mtu} qdisc #{attrs.qdisc}#{state_str}#{mode_str} group #{group_str}#{qlen_str}"
  puts "    link/#{interface_type(interface.type)}#{mac_str(attrs.address)}#{broadcast_str(attrs.broadcast)}"
end

def interface_type(type : UInt16)
  # see /usr/include/linux/if_arp.h for a complete list
  case type
  when 1_u16
    "ether"
  when 772_u16
    "loopback"
  when 0xFFFE_u16
    "none"
  else
    type.to_s
  end
end

def addr_str(addr)
  addr.map {|b| b.to_s(16).rjust(2, '0')}.join(":")
end
def mac_str(addr)
  if addr.nil?
    ""
  else
    " #{addr_str(addr)}"
  end
end

def broadcast_str(addr)
  if addr.nil?
    ""
  else
    " brd #{addr_str(addr)}"
  end
end
