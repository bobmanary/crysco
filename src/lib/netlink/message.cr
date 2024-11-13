module Netlink
  class Message

    abstract class Segment
      abstract def encode(io : IO::Memory)
      abstract def padded_size() : UInt32
    end

    getter size : UInt32

    def initialize
      @size = 0
      @segments = [] of Segment
    end

    def add_segment(segment : Segment)
      @segments << segment
      @size += segment.padded_size
    end

    def serialize
      buffer = IO::Memory.new

      @segments.each do |segment|
        segment.encode(buffer)
      end

      buffer
    end
  end
end
