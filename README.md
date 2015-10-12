# Bliftax

This is a simple library that parses a
[BLIF](https://www.ece.cmu.edu/~ee760/760docs/blif.pdf) file and does
operations used in logic optimization algorithms described in Chapter 4.10.2
in the book _Fundamentals of Digital Logic with Verilog Design_ by Stephen
Brown and Zvonko Vranesic.

As usual, thanks to the [Faker](https://github.com/stympy/faker) gem for
partially naming this gem.

## Installation

    $ bundle install
    $ rake install

## Usage

This gem currently only supports the following declarations for BLIF:

```
.model
.inputs
.outputs
.names
.latch
.clock
```

Following is the list of main features of this gem:

* star operators
* sharp operators
* coverage check (b is covered by a)
* finding minterms that an implicant covers
* finding the cost of an implicant

Here is an example usage of this gem.

```ruby
require 'bliftax'

model = Bliftax.new('path/to/blif_file')
model.gates.each do |gate|
  next if gate.implicants.size < 2

  starred = gate[0] * gate[1]
  sharped = gate[0].sharp(gate[1])
end

model.gates.each do |gate|
  gate.implicants.combination(2).each do |a, b|
    c = a * b
    covered = c.covers?(a)
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake rspec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/NigoroJr/bliftax.

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).

## Author
Naoki Mizuno
