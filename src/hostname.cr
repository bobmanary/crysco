require "lib_c"

lib LibC
  fun sethostname(name : Char*, len : SizeT) : Int
end

module Crysco::Hostname
  def self.set(name : String) : Bool
    buffer = name.to_slice
    unless LibC.sethostname(buffer, LibC::SizeT.new(buffer.size)) == 0
      raise RuntimeError.from_errno("Could not set hostname")
    end
    true
  end
end
