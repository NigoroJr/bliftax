require 'set'
require 'bliftax/implicant/bit'

class Bliftax
  # A class that represents an implicant of a gate.
  class Implicant
    # Look-up tables for the star and sharp operators
    # +---+---+---+---+
    # |A/B| 0 | 1 | - |
    # +---+---+---+---+
    # | 0 |   |   |   |
    # +---+---+---+---+
    # | 1 |   |   |   |
    # +---+---+---+---+
    # | - |   |   |   |
    # +---+---+---+---+
    #
    # Use it like: STAR_TABLE[a.bit][b.bit]
    STAR_TABLE = {
      Bit::OFF => {
        Bit::OFF => Bit::OFF,
        Bit::ON  => Bit::NULL,
        Bit::DC  => Bit::OFF
      },
      Bit::ON => {
        Bit::OFF => Bit::NULL,
        Bit::ON  => Bit::ON,
        Bit::DC  => Bit::ON
      },
      Bit::DC => {
        Bit::OFF => Bit::OFF,
        Bit::ON  => Bit::ON,
        Bit::DC  => Bit::DC
      }
    }
    SHARP_TABLE = {
      Bit::OFF => {
        Bit::OFF => Bit::EPSILON,
        Bit::ON  => Bit::NULL,
        Bit::DC  => Bit::EPSILON
      },
      Bit::ON => {
        Bit::OFF => Bit::NULL,
        Bit::ON  => Bit::EPSILON,
        Bit::DC  => Bit::EPSILON
      },
      Bit::DC => {
        Bit::OFF => Bit::ON,
        Bit::ON  => Bit::OFF,
        Bit::DC  => Bit::EPSILON
      }
    }

    attr_reader :inputs, :output

    def initialize(input_labels, output_label, str, is_null = false)
      @is_null = is_null

      return if str.empty?

      (input_bits, output_bit) = parse_bits(str)

      fail 'Input bit size mismatch' if input_labels.size != input_bits.size

      @inputs = []
      input_labels.each_with_index do |label, i|
        @inputs << Bit.new(label, input_bits.at(i), Bit::INPUT)
      end

      @output = Bit.new(output_label, output_bit, Bit::OUTPUT)
    end

    # The Star-operator.
    # As described in Chapter 4.10 in the Fundamentals of Digital Logic with
    # Verilog Design,
    #
    # A * B = C
    #
    # where
    #
    # * C = NULL if A_i * B_i = NULL for more than one i
    # * Otherwise, C_i = A_i * B_i when A_i * B_i != NULL, and C_i = x (don't
    #   care) for the coordinate where A_i * B_i = NULL
    def star(rhs)
      # Sanity check
      unless @inputs.size == rhs.inputs.size
        fail 'Two operands must have equal size for *-operator'
      end
      unless bits_valid?(@inputs.map(&:bit))
        fail 'Bad bit in LHS operand of star operator'
      end
      unless bits_valid?(rhs.inputs.map(&:bit))
        fail 'Bad bit in RHS operand of star operator'
      end

      result_bits = []
      @inputs.zip(rhs.inputs).each do |a, b|
        result_bits << STAR_TABLE[a.bit][b.bit]
      end

      result_is_null = result_bits.count(Bit::NULL) > 1
      unless result_is_null
        # C_i = DC if A_i * B_i == NULL
        result_bits.map! { |b| b == Bit::NULL ? Bit::DC : b }
      end

      # Construct a Implicant instance
      Implicant.new(@inputs.map(&:label),
                    @output.label,
                    bit_str(result_bits),
                    result_is_null)
    end
    alias_method :*, :star

    # The Sharp-operator.
    # Described in Chapter 4.10.1 in the Fundamentals of Digital Logic with
    # Verilog Design.
    #
    # A # B = C
    #
    # where
    #
    # * C = A if A_i # B_i = NULL for some i
    # * C = NULL if A_i # B_i = EPSILON for all i
    # * Otherwise, C = union of A_i = B_i' (negated) if A_i = x and B_i != x
    #
    # @param rhs [Implicant] the right hand side of the operation
    #
    # @return [Set<Implicant>] Note that the set size could be 1.
    def sharp(rhs)
      unless @inputs.size == rhs.inputs.size
        fail 'Two operands must have equal size for sharp operator'
      end
      unless bits_valid?(@inputs.map(&:bit))
        fail 'Bad bit in LHS operand of sharp operator'
      end
      unless bits_valid?(rhs.inputs.map(&:bit))
        fail 'Bad bit in RHS operand of sharp operator'
      end

      result_bits = []
      @inputs.zip(rhs.inputs).each do |a, b|
        result_bits << SHARP_TABLE[a.bit][b.bit]
      end

      # C = A if A_i # B_i = NULL for some i
      return Set.new([self]) if result_bits.any? { |bit| bit == Bit::NULL }

      # C = NULL if A_i # B_i = EPSILON for all i
      result_is_null = result_bits.all? { |bit| bit == Bit::EPSILON }
      return Set.new([Implicant.make_null]) if result_is_null

      # Set of Implicant to return
      result_set = Set.new

      @inputs.zip(rhs.inputs).each_with_index do |(a, b), i|
        # Check for A_i == DC and B_i != DC
        if a.bit == Bit::DC && b.bit != Bit::DC
          copy = @inputs.map(&:bit)
          copy[i] = b.bit == Bit::ON ? Bit::OFF : Bit::ON
          in_labels = @inputs.map(&:label)
          result = Implicant.new(in_labels, @output.label, bit_str(copy))
          result_set.add(result)
        end
      end

      result_set
    end

    # Finds the possible minterms that this implicant can represent.
    # For example, a bit string of 101 can only represent m_5, but 10- can
    # represent m_4 and m_5.
    #
    # @return [Set<Integer>] a set of minterms.
    def minterms
      set = Set.new

      bits = @inputs.map(&:bit)
      num_dc = bits.count(Bit::DC)
      str = bits.join
      # There are 2**num_dc combinations
      (2**num_dc).times do |i|
        str_copy = str.dup

        # Convert to binary form and pad with 0
        cnt_str = i.to_s(2).rjust(num_dc, '0')
        cnt_str.split('').each do |b|
          str_copy = str_copy.sub(Bit::DC, b)
        end
        set.add(str_copy.to_i(2))
      end

      set
    end

    # Returns the cost of this implicant.
    # A cost refers to the size of the cube, meaning how many don't-cares this
    # implicant has. For example, an implicant '1-00' has a cost of 3, whereas
    # '1--0' has a cost of 2.
    #
    # @return [Integer] the cost of this implicant.
    def cost
      @inputs.size - @inputs.map(&:bit).count(Bit::DC)
    end

    # Checks if this implicant covers the given implicant.
    # Implicant a covers b if all bit combinations that b can describe can
    # also be described by a.
    #
    # @param other [Implicant] the implicant to be compared against.
    #
    # @return [true, false] true if this covers the given implicant, false
    #   otherwise.
    def covers?(other)
      fail 'Argument must be an Implicant' unless other.is_a?(Implicant)

      @inputs.zip(other.inputs).each do |a, b|
        return false unless a.bit == b.bit || a.bit == Bit::DC
      end

      true
    end

    def null?
      @is_null
    end

    # Checks for equality.
    #
    # @param other [Object] whatever to compare against
    def ==(other)
      @inputs == other.inputs && @output == other.output
    end
    alias_method :eql?, :==

    # Returns the hash value of this instance.
    #
    # @return [Integer] the hash value of this instance.
    def hash
      [@inputs, @output].hash
    end

    # Return the string version of this implicant.
    #
    # @param show [:input, :output, :labels, Array<:input, :output, :labels>]
    #   what to show. If Array is used, corresponding information is appended.
    #
    # @return [String] string representation of this implicant.
    def to_s(show = [:input])
      show = [show] unless show.is_a?(Array)

      tokens = []

      if show.include?(:labels)
        # Only show the labels
        if show == [:labels]
          return [@inputs.map(&:label), @output.label].join(Bliftax::SPACE)
        end

        if show.include?(:input)
          tokens << 'INPUTS'
          @inputs.each do |b|
            tokens << format('%-8s %s', b.label, b.bit)
          end
        end
        if show.include?(:output)
          tokens << 'OUTPUT'
          tokens << format('%-8s %s', @output.label, @output.bit)
        end

        return tokens.join("\n") + "\n"
      end

      tokens << @inputs.map(&:bit).join if show.include?(:input)
      tokens << @output.bit if show.include?(:output)
      tokens.join(Bliftax::SPACE)
    end

    # Returns the string representation of this implicant.
    #
    # @return [String] the string representation of this implicant in BLIF
    #   format.
    def to_blif
      format '%s %s', @inputs.map(&:bit).join, @output.bit
    end

    # Creates a new NULL Implicant.
    #
    # @return [Implicant] a null Implicant
    def self.make_null
      Implicant.new([], Bliftax::EMPTY, Bliftax::EMPTY, true)
    end

    private

    # Parses the bit string and returns the bits for inputs and outputs.
    #
    # @param str [String] the string representation of the input and output
    #   bits. Input and output bits must be separated by a whitespace.
    #
    # @return [Array] contains exactly two elements, the first being the input
    #   bits in String and the second being the output bit in String.
    #
    # @example Parse a String representation of bits.
    #   parse_bits('010 1')
    #   # => [['0', '1', '0'], '1']
    def parse_bits(str)
      is_single = str.split(' ').size == 1

      # Constant gate (likely vcc or gnd)
      if is_single
        input_bits = []
        output_bit = str
      else
        # Parse strings that look like "0001 1"
        (input_bits, output_bit) = str.split(' ')
        input_bits = input_bits.split('')
      end

      [input_bits, output_bit]
    end

    # Checks whether all the bits are either 1, 0, or DC.
    #
    # @param bits [Array<String>]
    #
    # @return [true, false] true if all the bits are 1, 0, or DC.
    def bits_valid?(bits)
      bits.all? do |bit|
        [Bit::ON, Bit::OFF, Bit::DC].any? { |b| bit == b }
      end
    end

    # Returns the BLIF-style representation of this implicant.
    # This method assumes that the output bit is 1 because BLIF only states
    # combinations that result in output of 1.
    #
    # @return [String] representation of the bits in this implicant. The
    #   output bit is separated from the input bits by one space.
    def bit_str(bits)
      format '%s 1', bits.join
    end
  end
end
