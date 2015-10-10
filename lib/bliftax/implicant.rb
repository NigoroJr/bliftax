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

    def initialize(labels, str, is_null = false)
      (*input_labels, output_label) = labels
      (input_bits, output_bit) = in_out_bits(str, labels.size == 1)

      if input_labels.size != input_bits.size
        fail 'Labels and bits size do not match'
      end

      @inputs = []
      input_labels.each_with_index do |l, i|
        @inputs << Bit.new(l, input_bits.at(i), Bit::INPUT)
      end

      @output = Bit.new(output_label, output_bit, Bit::OUTPUT)

      @is_null = is_null
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
      unless bits_ok(@inputs.map(&:bit)) && bits_ok(rhs.inputs.map(&:bit))
        fail 'Bad bit in operand of star operator'
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
      Implicant.new(labels, bit_str(result_bits), result_is_null)
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
    # * C = NULL if A_i # B_i = EPLISON for all i
    # * Otherwise, C = union of A_i = B_i' (negated) if A_i = x and B_i != x
    #
    # Returns a Set of Implicant. Note that the set size could be 1.
    def sharp(rhs)
      # Sanity check
      unless @inputs.size == rhs.inputs.size
        fail 'Two operands must have equal size for #-operator'
      end
      unless bits_ok(@inputs.map(&:bit)) && bits_ok(rhs.inputs.map(&:bit))
        fail 'Bad bit in operand of sharp operator'
      end

      result_bits = []
      @inputs.zip(rhs.inputs).each do |a, b|
        result_bits << SHARP_TABLE[a.bit][b.bit]
      end

      result_is_null = result_bits.any? { |bit| bit == Bit::NULL }
      result_is_null ||= result_bits.all? { |bit| bit == Bit::EPSILON }

      # Don't bother going further
      str = bit_str(result_bits)
      return Set.new([Implicant.new(labels, str, true)]) if result_is_null

      # Set of Implicant to return
      result_set = Set.new

      @inputs.zip(rhs.inputs).each_with_index do |(a, b), i|
        # Check for A_i == DC and B_i != DC
        if a.bit == Bit::DC && b.bit != Bit::DC
          copy = @inputs.map(&:bit)
          copy[i] = b.bit == Bit::ON ? Bit::OFF : Bit::ON
          result_set.add(Implicant.new(labels, bit_str(copy)))
        end
      end

      result_set
    end

    # Checks if this Implicant covers the given Implicant
    def covers?(other)
      fail 'Argument must be a Implicant' unless other.is_a?(Implicant)

      @inputs.zip(other.inputs).each do |a, b|
        return false unless a.bit == b.bit || a.bit == Bit::DC
      end

      true
    end

    def null?
      @is_null
    end

    # Checks if the implicants are equal
    def ==(other)
      @inputs == other.inputs && @output == other.output
    end

    def eql?(other)
      self == other
    end

    def hash
      [@inputs, @output].hash
    end

    # String-ify this implicant
    def to_s
      str = ''
      str << "INPUTS:\n" unless @inputs.empty?
      @inputs.each do |bit|
        str << format("%s\n", bit)
      end
      str << @output.to_s
      str
    end

    # Returns the String representation of this Implicant.
    # Used when outputting in BLIF.
    def to_blif
      format '%s %s', @inputs.map(&:bit).join, @output.bit
    end

    # Returns an Array of String that has labels for this Implicant
    def labels
      labels = @inputs.map(&:label)
      labels << @output.label
      labels
    end

    private

    # Parses the bit string and returns the bits for inputs and outputs.
    #
    # Examples
    #
    #   in_out_bits('010 1', false)
    #   # => [['0', '1', '0'], 1]
    def in_out_bits(str, is_single)
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
    def bits_ok(port)
      port.all? do |bit|
        [Bit::ON, Bit::OFF, Bit::DC].any? { |b| bit == b }
      end
    end

    # Given an Array of bits, return the BLIF-style bit string.
    # This method assumes that the bits given are input bits, so it appends a
    # 1 as the output.
    def bit_str(bits)
      format '%s 1', bits.join('')
    end
  end
end
