require "colorize"

module Netlink::Debug
  def self.print_bytes(slice : Bytes)
    i = 0
    j = 0
    slice.each do |n|
      if i == 0
        print j.to_s.rjust(4).colorize.dark_gray
        print "    "
      end
      print n.to_s.rjust(4)
      if n >= 32 && n <= 126
        print " #{String.new(pointerof(n), 1)}".colorize.white
      else
        print " .".colorize.dark_gray
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

  def self.print_bytes(slice : IO::Memory)
    i = 0
    j = 0

    slice.each_byte do |n|
      if i == 0
        print j.to_s.rjust(4).colorize.dark_gray
        print "    "
      end
      print n.to_s.rjust(4)
      if n >= 32 && n <= 126
        print " #{String.new(pointerof(n), 1)}".colorize.white
      else
        print " .".colorize.dark_gray
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
    slice.rewind
  end
end
