# output something similar to running iproute2's `ip link` command,
# using the library's high level API.

require "../socket_patch"
require "../socket"
require "../route/protocol/protocol"
require "../route/route"

links = Netlink::Route.get_links

links.each do |link|
  puts link.name
end
