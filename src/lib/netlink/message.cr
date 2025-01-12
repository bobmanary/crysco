# require "./debug"

module Netlink
  class Message

    abstract class Segment
      abstract def encode(io : IO::Memory)
      abstract def padded_size() : UInt32
    end

    getter size : UInt32

    def initialize(header : MsgHeader)
      @size = header.padded_size
      @segments = [header] of Segment
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

      # set the message length
      buffer.rewind
      buffer.write_bytes(@size)
      buffer.rewind

      # Debug.print_bytes(buffer)

      buffer
    end
  end
end
