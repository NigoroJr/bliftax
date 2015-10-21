require 'bliftax/gate'
require 'bliftax/implicant'
require 'bliftax/optimizer'
require 'bliftax/version'

# A class that parses a BLIF file.
class Bliftax
  attr_accessor :name, :inputs, :outputs, :latches, :clocks, :gates

  DECL_MODEL = '.model'
  DECL_INPUTS = '.inputs'
  DECL_OUTPUTS = '.outputs'
  DECL_NAMES = '.names'
  DECL_LATCH = '.latch'
  DECL_CLOCK = '.clock'
  DECL_END = '.end'

  # One space for readability.
  SPACE = ' '
  # Empty string for readability.
  EMPTY = ''

  # Initializes the object.
  #
  # @param str [String] filename or text to parse.
  def initialize(str = nil)
    @latches = []
    @clocks = []
    @gates = []

    parse(str) unless str.nil?
  end

  # Parses a BLIF file.
  #
  # @param str [String] filename or the text to parse.
  #
  # @return [Bliftax] the parsed BLIF file.
  def parse(str)
    fh = File.exist?(str) ? File.open(str) : StringIO.new(str)
    lines = read_continuous_lines(fh)

    lines.each_with_index do |line, i|
      (decl, *following) = line.split(SPACE)

      case decl
      when DECL_MODEL
        @name = following.first
      when DECL_INPUTS
        @inputs = following
      when DECL_OUTPUTS
        @outputs = following
      when DECL_NAMES
        @gates << parse_gate(following, lines, i + 1)
      when DECL_LATCH
        @latches << following
      when DECL_CLOCK
        @clocks << following
      when DECL_END
        break
      when /^[^\.]/
        next
      else
        fail "Unknown decl encountered: I don't understand `#{decl}' :("
      end
    end

    self
  end

  # Parse one gate from the input.
  #
  # @param labels [Array<String>] labels of the inputs and output.
  # @param lines [Array<String>] all the lines in the current BLIF file.
  # @param i [Integer] index of in lines to start from.
  #
  # @return [Gate] the gate that was parsed.
  def parse_gate(labels, lines, i)
    gate = Gate.new(labels)

    loop do
      # If no truth table exists, then that's all 0
      bit_str = lines[i].start_with?('.') ? Implicant::Bit::OFF : lines[i]
      gate.add_implicant(bit_str)

      i += 1

      break if lines[i].nil? || lines[i].empty? || lines[i].start_with?('.')
    end

    gate
  end

  # Returns a string representation of this gate in BLIF format.
  #
  # @return [String] this gate in BLIF format.
  def to_blif
    in_labels = @inputs.join(SPACE)
    out_labels = @outputs.join(SPACE)
    str = <<-EOF
.model #{@name}
.inputs #{in_labels}
.outputs #{out_labels}
    EOF

    @gates.each do |gate|
      str << gate.to_blif
    end

    @latches.each do |l|
      str << format(".latch %s\n", l.join(SPACE))
    end

    @clocks.each do |c|
      str << format(".clock %s\n", c.join(SPACE))
    end

    str << ".end\n"
  end

  # Duplicates this object.
  #
  # @return [Bliftax] the deep copy of this object.
  def dup
    copy = Bliftax.new
    copy.name = @name.dup
    copy.inputs = @inputs.dup
    copy.outputs = @outputs.dup
    copy.latches = @latches.dup
    copy.clocks = @clocks.dup
    copy.gates = @gates.dup
    copy
  end

  private

  # Reads in the BLIF file creating an Array with each element being the
  # logical line (removing comments and joining lines that end with
  # backslash with the next line).
  #
  # @param fh [IO] the file handle to read from.
  #
  # @return [Array] each element being the logical lines with comments and
  #   backslashes removed. Lines ending with a backslash gets joined with the
  #   next line.
  def read_continuous_lines(fh)
    # Read in the entire BLIF file into an array so that
    # we can "peek" into the future.
    lines = []
    fh.each_line do |line|
      line.chomp!

      # Skip comment lines
      next if line.start_with?('#')
      next if line.strip.empty?

      continuous_lines = []
      loop do
        line = strip_comments(line)
        continuous_lines << strip_trailing_backslash(line)

        # If line ends with a backslash, there's more to come
        break unless line.end_with?('\\')

        line = fh.gets.chomp
      end

      lines << continuous_lines.join(SPACE).strip
    end

    lines
  end

  # Removes the trailing comments from a string.
  #
  # @param str [String] the original string.
  #
  # @return [String] string with the trailing whitespace and comments removed.
  def strip_comments(str)
    str.sub(/\s*\#.*$/, EMPTY).strip
  end

  # Removes the trailing backslash from a string.
  #
  # @param str [String] the original string.
  #
  # @return [String] string with the trailing backslash removed.
  def strip_trailing_backslash(str)
    str.sub(/\\/, EMPTY)
  end
end
