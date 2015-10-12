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

```ruby
require 'bliftax'

model = Bliftax.new('path/to/blif_file')
model.inputs
model.outputs
model.latches
model.clocks
model.implicants
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