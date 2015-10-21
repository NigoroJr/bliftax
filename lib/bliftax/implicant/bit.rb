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

      # Creates a new Bit instance.
      #
      # @param label [String] the label corresponding to this bit.
      # @param bit [String] the bit (can be 1, 0, -, E, or N).
      # @param type [Symbol] the type of this bit (input or output).
      def initialize(label, bit, type)
        fail 'Label has to be a String' unless label.is_a?(String)
        fail 'Bit has to be a String' unless bit.is_a?(String)

        @label = label
        @bit = bit
        @type = type
      end

      # Checks for equality.
      #
      # @param other [Object] whatever to compare against.
      #
      # @return [true, false] true if two bits are equal, false otherwise.
      def ==(other)
        @bit == other.bit && @type == other.type
      end
      alias_method :eql?, :==

      # Returns the hash value of this instance.
      #
      # @return [Integer] the hash value of this instance.
      def hash
        [@bit, @type].hash
      end

      # Return the string version of this bit.
      #
      # @return [String] string representation of this bit.
      def to_s
        format '%-6s %-8s %s', @type.to_s.upcase, @label, @bit
      end
    end
  end
end
