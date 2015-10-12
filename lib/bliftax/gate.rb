require 'bliftax/implicant'

class Bliftax
  # Represents one logic gate in the BLIF file
  class Gate

    attr_reader :input_labels, :output_label
    attr_accessor :implicants

    # Initalizes this gate with the labels for inputs and output.
    #
    # @param labels [Array] the label names for the inputs and output. The
    #   last element in the Array is the output label.
    def initialize(labels)
      (*@input_labels, @output_label) = labels
      @implicants = []
    end

    # Adds an Implicant to this gate.
    #
    # @param implicant [Implicant, String, Array<Implicant, String>] the
    #   implicant to add. If a String is passed, it is considered to be a
    #   two-token string with the first being the input bits and the second
    #   being the output bit. For example, '010 1' represents the three inputs
    #   being 0, 1, 0 and the output being 1 in this case. If an Array is
    #   given, it will add all of the implicants.
    def add_implicant(implicant)
      case implicant
      when Implicant
        @implicants << implicant
      when String
        @implicants << Implicant.new(@input_labels, @output_label, implicant)
      when Array
        # Recursive call
        implicant.each { |i| add(i) }
      end
    end
    alias_method :<<, :add_implicant

    # Returns the specified implicant.
    #
    # @param index [Integer] the index of the implicant.
    #
    # @return [Implicant] the specified implicant.
    def [](index)
      @implicants[index]
    end

    # Returns the size of the inputs.
    #
    # @return [Integer] the size of the inputs.
    def input_size
      @input_labels.size
    end

    # Returns a string representation of this gate in BLIF format.
    #
    # @return [String] this gate in BLIF format
    def to_blif
      str = format(".names %s %s\n",
                   @input_labels.join(SPACE),
                   @output_label)
      @implicants.each do |implicant|
        str += format("%s\n", implicant.to_blif)
      end

      str
    end
  end
end
