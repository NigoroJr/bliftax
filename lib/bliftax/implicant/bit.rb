class Bliftax
  class Implicant
    # A class that represents one bit of an implicant
    class Bit
      ON = '1'
      OFF = '0'
      # Don't care
      DC = '-'
      EPSILON = 'E'
      NULL = 'N'

      attr_accessor :label, :bit, :type

      INPUT = :input
      OUTPUT = :output

      def initialize(label, bit, type)
        fail 'Label has to be a String' unless label.is_a?(String)
        fail 'Bit has to be a String' unless bit.is_a?(String)

        @label = label
        @bit = bit
        @type = type
      end

      def ==(other)
        @bit == other.bit && @type == other.type
      end

      def eql?(other)
        self == other
      end

      def hash
        [@bit, @type].hash
      end

      def to_s
        format '%-6s %-8s %s', @type.to_s.upcase, @label, @bit
      end
    end
  end
end
