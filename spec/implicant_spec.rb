require 'spec_helper'

describe Bliftax::Implicant do
  let!(:blif) { Bliftax.new }
  # Using ==
  let(:implicant_operator_equals) do
    <<-EOF
.model equals
.inputs a b c
.outputs out

.names a b out
00 1
00 1
01 1
11 1

.names a b c
00 1
01 1

.end
    EOF
  end
  # The Star-operator
  let(:implicant_operator_star) do
    <<-EOF
.model star_operator
.inputs a b c d
.outputs out
.names a b c d out
0111 1  # 0: Base (compare against this)
0011 1  # 1: One NULL
1011 1  # 2: More than one NULL
-1-1 1  # 3: No NULL involved
    EOF
  end
  # The Sharp-operator
  let(:implicant_operator_sharp) do
    <<-EOF
.model sharp_operator
.inputs a b c d e
.outputs out
.names a b c d e out
1-100 1   # 0: Base (compare against this)
-010- 1   # 1: All epsilon but one
0-000 1   # 2: All epsilon hence NULL
-011- 1   # 3: Has one NULL hence ends up NULL
# Add some more test cases
-1-0- 1   # 4: Base (for getting multiple results)
110-1 1   # 5: Results in three implicants
    EOF
  end

  context 'when parsing' do
    it 'parses all the gates' do
      model = blif.parse(implicant_operator_equals)
      expect(model.gates.size).to eq 2
    end

    it 'parses all the implicants' do
      model = blif.parse(implicant_operator_equals)
      expect(model.gates.first.implicants.size).to eq 4
    end
  end

  context 'when using operators' do
    it 'knows when two implicants are equal' do
      model = blif.parse(implicant_operator_equals)
      first_gate = model.gates.first
      expect(first_gate[0]).to eq first_gate[1]
    end

    context 'using star operator' do
      let(:input_labels) { ('a'..'d').to_a }
      let(:output_label) { 'out' }
      let!(:model) { blif.parse(implicant_operator_star) }
      let!(:gate) { model.gates.first }

      it 'processes at-least-one-NULL case' do
        correct = Bliftax::Implicant.new(input_labels, output_label, '0-11 1')
        expect(gate[0].star(gate[1])).to eq correct
      end

      it 'processes case resulting in NULL' do
        expect(gate[0].star(gate[2]).null?).to eq true
      end

      it 'processes case where no NULL is involved' do
        correct = Bliftax::Implicant.new(input_labels, output_label, '0111 1')
        expect(gate[0].star(gate[3])).to eq correct
      end
    end

    context 'using sharp operator' do
      let(:input_labels) { ('a'..'e').to_a }
      let(:output_label) { 'out' }
      let!(:model) { blif.parse(implicant_operator_sharp) }
      let!(:gate) { model.gates.first }

      it 'results in NULL because all epsilon' do
        results = gate[0].sharp(gate[2])
        expect(results.to_a.all? { |r| r.null? }).to eq true
      end

      it 'results in NULL because it has one NULL' do
        results = gate[0].sharp(gate[3])
        expect(results.to_a.all? { |r| r.null? }).to eq true
      end

      it 'results in multiple implicants' do
        correct_results = Set.new([
          Bliftax::Implicant.new(input_labels, output_label, '01-0- 1'),
          Bliftax::Implicant.new(input_labels, output_label, '-110- 1'),
          Bliftax::Implicant.new(input_labels, output_label, '-1-00 1')
        ])
        results = gate[4].sharp(gate[5])
        expect(results).to eq correct_results
      end
    end
  end

  context 'checking coverage' do
    let(:input_labels) { ('a'..'e').to_a }
    let(:output_label) { 'out' }
    let(:a) { Bliftax::Implicant.new(input_labels, output_label, '0--01 1') }
    let(:b) { Bliftax::Implicant.new(input_labels, output_label, '0-101 1') }

    it 'knows when it covers another Implicant' do
      expect(a.covers?(b)).to eq true
    end

    it 'knows when it does not cover another Implicant' do
      expect(b.covers?(a)).to eq false
    end
  end

  context 'finding minterms' do
    let(:input_labels) { ('a'..'e').to_a }
    let(:output_label) { 'out' }
    let(:a) { Bliftax::Implicant.new(input_labels, output_label, '01101 1') }
    let(:b) { Bliftax::Implicant.new(input_labels, output_label, '0--01 1') }

    it 'finds exactly one minterm for terms that do not have DC' do
      expect(a.minterms).to eq Set.new([13])
    end

    it 'finds multiple minterms' do
      expect(b.minterms).to eq Set.new([1, 5, 9, 13])
    end
  end
end
