# output something similar to running iproute2's `ip link` command,
# using the library's high level API.

require "../socket_patch"
require "../socket"
require "../route/protocol/protocol"
require "../route/route"

links = Netlink::Route.get_links

links.each do |link|
  addr = link.address
  brd = link.broadcast
  mac = addr.nil? ? "" : addr.map {|b| b.to_s(16).rjust(2, '0')}.join(":")
  broadcast = brd.nil? ? "" : brd.map {|b| b.to_s(16).rjust(2, '0')}.join(":")
  puts "#{0}: #{link.ifname} <> mtu #{link.mtu} qdisc #{link.qdisc} state ? mode ? group ?\n    link/? #{mac} brd #{broadcast}"

end
