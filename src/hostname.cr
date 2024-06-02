require "lib_c"
require "./lib/linux"

module Crysco::Hostname
  def self.set(name : String) : Bool
    buffer = name.to_slice
    unless Linux.sethostname(buffer, LibC::SizeT.new(buffer.size)) == 0
      raise RuntimeError.from_errno("Could not set hostname")
    end
    true
  end
end
