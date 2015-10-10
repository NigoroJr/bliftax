require 'spec_helper'

describe Bliftax do
  let!(:blif) { Bliftax.new }
  let(:blif_backslash) do
    <<-EOF
.model backslash
.inputs a\\
b\\
c d
.outputs out
.end
    EOF
  end
  let(:blif_comments) do
    <<-EOF
.model comments
# Hello world
# Here's a comment
.inputs a b c       # And some more comments
.outputs out
# Getting tired of comments?
.end
    EOF
  end
  let(:blif_normal) do
    <<-EOF
.model normal
.inputs a b c
.outputs out
.names a b c out
000 1
001 1
101 1
.end
    EOF
  end

  it 'has a version number' do
    expect(Bliftax::VERSION).not_to be nil
  end

  context 'when parsing' do
    it 'concatenates lines ending with a backslash' do
      model = blif.parse(blif_backslash)
      expect(model.inputs.size).to eq 4
    end

    it 'ignores comment lines' do
      model = blif.parse(blif_comments)
      expect(model.inputs.size).to eq 3
    end
  end

  it 'outputs in correct BLIF format' do
    out = blif.parse(blif_normal).to_blif
    expect(out).to eq blif_normal
  end
end
