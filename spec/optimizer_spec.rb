require 'spec_helper'

describe Bliftax::Optimizer do
  # Sample BLIFs and their correct outputs {{{
  # ab/c| 0 1
  # --- +----
  # 00  | 0 0
  # 01  | 1 0
  # 11  | 1 1
  # 10  | 0 0
  # Optimized:
  # f = ab + bc'
  let(:sample1) do
    <<-EOF
.model sample1
.inputs a b c
.outputs out
.names a b c out
010 1
110 1
111 1
.end
    EOF
  end

  let(:sample1_correct) do
    Set.new([
      Bliftax::Implicant.make_dummy('-10'),
      Bliftax::Implicant.make_dummy('11-')
    ])
  end

  # ab/cd| 00 01 11 10
  # -----+------------
  # 00   |  0  0  1  1
  # 01   |  0  1  1  1
  # 11   |  0  1  0  1
  # 10   |  0  0  1  1
  #
  # f = a'c + b'c + bc'd + cd'
  let(:sample2) do
    <<-EOF
.model sample2
.inputs a b c d
.outputs out
.names a b c d out
-01- 1
-101 1
01-1 1
0-1- 1
--10 1
.end
    EOF
  end

  let(:sample2_correct) do
    Set.new([
      Bliftax::Implicant.make_dummy('0-1-'),
      Bliftax::Implicant.make_dummy('-01-'),
      Bliftax::Implicant.make_dummy('-101'),
      Bliftax::Implicant.make_dummy('--10')
    ])
  end

  # f = a'bc' + c'd + bd + ab'cd'
  let(:sample3) do
    <<-EOF
.model sample3
.inputs a b c d
.outputs out
.names a b c d out
0001 1
0100 1
0101 1
0111 1
1001 1
1010 1
1101 1
1111 1
.end
    EOF
  end

  let(:sample3_correct) do
    Set.new([
      Bliftax::Implicant.make_dummy('1010'),
      Bliftax::Implicant.make_dummy('010-'),
      Bliftax::Implicant.make_dummy('--01'),
      Bliftax::Implicant.make_dummy('-1-1')
    ])
  end

  # Sample that has no optimal solution
  #
  # ab/c| 0 1
  # --- +----
  # 00  | 1 0
  # 01  | 0 1
  # 11  | 1 0
  # 10  | 0 1
  #
  # Optimized
  # f = a'b'c' + a'bc + abc' + ab'c
  let(:sample4) do
    <<-EOF
.model sample4
.inputs a b c
.outputs out
.names a b c out
000 1
011 1
110 1
101 1
.end
    EOF
  end

  let(:sample4_correct) do
    Set.new([
      Bliftax::Implicant.make_dummy('000'),
      Bliftax::Implicant.make_dummy('011'),
      Bliftax::Implicant.make_dummy('110'),
      Bliftax::Implicant.make_dummy('101')
    ])
  end

  # A 6-variable logic optimization
  # Solution calculated using
  # http://www.32x8.com/var6
  #
  # Optimized:
  # f = a'b'c'd' + a'b'ce' + a'cef' + a'cdf' + a'bef
  let(:sample5) do
    <<-EOF
.model sample5
.inputs a b c d e f
.outputs out
.names a b c d e f out
000000 1
000001 1
000010 1
000011 1
001000 1
001001 1
001010 1
001100 1
001101 1
001110 1
010011 1
010111 1
011010 1
011011 1
011100 1
011110 1
011111 1
.end
    EOF
  end

  let(:sample5_correct) do
    Set.new([
      Bliftax::Implicant.make_dummy('0000--'),
      Bliftax::Implicant.make_dummy('001-0-'),
      Bliftax::Implicant.make_dummy('0-1-10'),
      Bliftax::Implicant.make_dummy('0-11-0'),
      Bliftax::Implicant.make_dummy('01--11')
    ])
  end

  # 8-variable
  let(:sample6) do
    <<-EOF
.model sample6
.inputs a b c d e f g h
.outputs out
.names a b c d e f g h out
00010110 1
00010111 1
00011111 1
00100000 1
00101100 1
00101110 1
00110110 1
00111010 1
01000001 1
01000100 1
01001001 1
01001101 1
01010001 1
01010011 1
01010100 1
01010110 1
01011101 1
01011111 1
01100010 1
01100100 1
01100110 1
01101111 1
01110000 1
01110001 1
01110011 1
01110100 1
01110101 1
01110110 1
01110111 1
01111000 1
10000000 1
10000100 1
10000110 1
10010100 1
10011000 1
10011001 1
10011010 1
10011011 1
10011111 1
10100001 1
10100101 1
10101000 1
10101011 1
10101100 1
10110101 1
10111100 1
11001010 1
11010010 1
11010110 1
11101000 1
.end
    EOF
  end

  let(:sample6_correct) do
    Set.new([
      Bliftax::Implicant.make_dummy('0--10110'),
      Bliftax::Implicant.make_dummy('01--0100'),
      Bliftax::Implicant.make_dummy('01-100-1'),
      Bliftax::Implicant.make_dummy('01110--1'),
      Bliftax::Implicant.make_dummy('100110--'),
      Bliftax::Implicant.make_dummy('0001011-'),
      Bliftax::Implicant.make_dummy('0-011111'),
      Bliftax::Implicant.make_dummy('-0011111'),
      Bliftax::Implicant.make_dummy('001011-0'),
      Bliftax::Implicant.make_dummy('0100-001'),
      Bliftax::Implicant.make_dummy('010-1101'),
      Bliftax::Implicant.make_dummy('01100-10'),
      Bliftax::Implicant.make_dummy('0111-000'),
      Bliftax::Implicant.make_dummy('10000-00'),
      Bliftax::Implicant.make_dummy('100001-0'),
      Bliftax::Implicant.make_dummy('100-0100'),
      Bliftax::Implicant.make_dummy('10100-01'),
      Bliftax::Implicant.make_dummy('101-0101'),
      Bliftax::Implicant.make_dummy('1-101000'),
      Bliftax::Implicant.make_dummy('101-1100'),
      Bliftax::Implicant.make_dummy('11010-10'),
      Bliftax::Implicant.make_dummy('00100000'),
      Bliftax::Implicant.make_dummy('00111010'),
      Bliftax::Implicant.make_dummy('01101111'),
      Bliftax::Implicant.make_dummy('10101011'),
      Bliftax::Implicant.make_dummy('11001010')
    ])
  end
  # }}}

  it 'finds the optimal solution to sample1' do
    gate = Bliftax.new(sample1).gates.first
    expect(Bliftax::Optimizer.optimize(gate)).to eq sample1_correct
  end

  it 'finds the optimal solution to sample2' do
    gate = Bliftax.new(sample2).gates.first
    expect(Bliftax::Optimizer.optimize(gate)).to eq sample2_correct
  end

  it 'finds the optimal solution to sample3' do
    gate = Bliftax.new(sample3).gates.first
    expect(Bliftax::Optimizer.optimize(gate)).to eq sample3_correct
  end

  it 'finds the optimal solution to sample4' do
    gate = Bliftax.new(sample4).gates.first
    expect(Bliftax::Optimizer.optimize(gate)).to eq sample4_correct
  end

  it 'finds the optimal solution to sample5' do
    gate = Bliftax.new(sample5).gates.first
    expect(Bliftax::Optimizer.optimize(gate)).to eq sample5_correct
  end

  it 'finds the optimal solution to sample6' do
    gate = Bliftax.new(sample6).gates.first
    expect(Bliftax::Optimizer.optimize(gate)).to eq sample6_correct
  end
end
