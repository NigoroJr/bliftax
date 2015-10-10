require 'bliftax/version'
require 'bliftax/implicant'

# A class that parses a BLIF file.
class Bliftax
  attr_accessor :name, :inputs, :outputs, :latches, :clocks, :gates

  # Decl's for BLIF
  MODEL = '.model'
  INPUTS = '.inputs'
  OUTPUTS = '.outputs'
  NAMES = '.names'
  LATCH = '.latch'
  CLOCK = '.clock'
  END_MODEL = '.end'

  # One space
  SPACE = ' '
  # Empty strng
  EMPTY = ''

  # Initializes the object.
  #
  # str: String for a filename or text to parse (optional)
  def initialize(str = nil)
    @latches = []
    @clocks = []
    @gates = []

    parse(str) unless str.nil?
  end

  # Parses a BLIF file.
  #
  # str: String for a filename or text to parse (optional)
  def parse(str)
    fh = File.exist?(str) ? File.open(str) : StringIO.new(str)
    lines = read_continuous_lines(fh)

    lines.each_with_index do |line, i|
      (decl, *following) = line.split(SPACE)

      case decl
      when MODEL
        @name = following.first
      when INPUTS
        @inputs = following
      when OUTPUTS
        @outputs = following
      when NAMES
        @gates << parse_names(following, lines, i + 1)
      when LATCH
        @latches << following
      when CLOCK
        @clocks << following
      when END_MODEL
        break
      when /^[^\.]/
        next
      else
        fail "Unknown decl encountered: I don't understand `#{decl}' :("
      end
    end

    self
  end

  # Parse the truth table creating an Implicant for each term (e.g. "001 1").
  def parse_names(labels, lines, i)
    implicants = []

    loop do
      # If no truth table exists, then that's all 0
      if lines[i].start_with?('.')
        implicants << Implicant.new(labels, Implicant::Bit::OFF)
      else
        implicants << Implicant.new(labels, lines[i])
      end

      i += 1

      break if lines[i].nil? || lines[i].empty? || lines[i].start_with?('.')
    end

    implicants
  end

  def to_blif
    in_labels = @inputs.join(SPACE)
    out_labels = @outputs.join(SPACE)
    str = <<-EOF
.model #{@name}
.inputs #{in_labels}
.outputs #{out_labels}
    EOF

    @gates.each do |g|
      str << format('.names %s', g.first.labels.join(SPACE)) << "\n"
      g.each do |implicant|
        str << implicant.to_blif << "\n"
      end
    end

    @latches.each do |l|
      str << format(".latch %s\n", l.join(SPACE))
    end

    @clocks.each do |c|
      str << format(".clock %s\n", c.join(SPACE))
    end

    str << ".end\n"
  end

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
  # fh: File handle
  #
  # Returns an Array of logical lines.
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

  def strip_comments(str)
    str.sub(/\s*\#.*$/, EMPTY)
  end

  def strip_trailing_backslash(str)
    str.sub(/\\/, EMPTY)
  end
end
