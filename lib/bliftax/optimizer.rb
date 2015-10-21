class Bliftax
  # A module that does 2-level logic optimization
  module Optimizer
    module_function

    # Does 2-level logic optimization to the given gate (a set of implicants).
    # This is done in the following steps (as described in the book
    # Fundamentals of Digital Logic with Verilog Design).
    #
    # 1. Find all prime implicants by using the star operator until the
    #    resulting set of implicants is the same as the previous round.
    # 2. Apply the sharp operation to one of the prime implicants against all
    #    other implicants. The operation is cascaded. If the result is not
    #    null, it is an essential prime implicant. Do this for all prime
    #    implicants.
    # 3. For the non-essential prime implicants, remove the ones that can be
    #    covered by some other implicant but with less cost.
    # 4. For the remaining implicants, use the branching heuristic to find the
    #    set of prime implicants with the minimum cost.
    #
    # @param gate [Bliftax::Gate, Set<Implicant>, Array<Implicant>] the set of
    #   implicants to be optimized.
    #
    # @return [Set<Implicant>] the resulting optimized set of implicants that
    #   covers the same minterms.
    def optimize(gate)
      implicants = gate.is_a?(Bliftax::Gate) ? gate.implicants : gate
      primes = get_prime_implicants(implicants)

      essentials = get_essential_implicants(primes)

      # Essential implicants will always be essential
      primes -= essentials

      # Find minterms that still needs to be covered
      need_cover = implicants.map(&:minterms).to_set.flatten
      need_cover -= essentials.map(&:minterms).to_set.flatten

      # Remove implicants with higher cost
      primes.to_a.permutation(2).each do |a, b|
        # If b has same coverage but cheaper
        if a.cost > b.cost && (a.minterms & need_cover) <= b.minterms
          primes.delete(a)
        end
      end

      # Branching heuristic
      to_use = branching(need_cover, primes)

      essentials.union(to_use)
    end

    # Returns the prime implicants of the given set of implicants.
    # This method successively applies the star operations to the given
    # implicants to find the prime implicants.
    #
    # @param implicants [Set<Implicant>, Array<Implicant>] the original set of
    #   implicants.
    #
    # @return [Set<Implicant>] a set of prime implicants.
    def get_prime_implicants(implicants)
      # Use star operator to find prime implicants
      star_set = Set.new(implicants)
      prev_set = Set.new

      loop do
        prev_set = star_set.dup
        prev_set.to_a.combination(2).each do |a, b|
          result = a * b
          star_set.add(result) unless result.null?
        end

        # Remove redundant implicants
        union = star_set.union(prev_set)
        union.to_a.permutation(2).each do |a, b|
          star_set.delete(b) if a.covers?(b)
        end

        break if star_set == prev_set
      end

      star_set
    end

    # Finds the essential implicants of the given set of implicants.
    # This method applies the sharp operation to an implicant against each of
    # the other implicants in the set, and adds the tested implicant if and
    # only if the result of the cascaded sharp operation is not null.
    #
    # @param implicants [Set<Implicant>, Array<Implicant>] the original set of
    #   implicants.
    #
    # @return [Set<Implicant>] the essential implicants of the given set of
    #   implicants.
    def get_essential_implicants(implicants)
      sharp_set = Set.new

      implicants.each do |a|
        result_set = Set.new([a])

        implicants.each do |b|
          next if b == a

          copy = result_set.dup
          result_set.clear
          copy.each do |new_a|
            result_set.add(new_a.sharp(b))
          end
          result_set.flatten!
          result_set.delete_if { |s| s.null? }
        end

        sharp_set.add(a) unless result_set.empty?
      end

      sharp_set
    end

    # Cost heuristic.
    # If an Implicant is given, the cost of that Implicant is returned.
    # Otherwise, the sum of the number of implicants and the cost of each
    # implicant is returned as the cost for that collection.
    #
    # @param what [Implicant, #to_a<#cost>] the thing to be evaluated.
    #
    # @return the evaluated cost.
    def cost(what)
      return what.cost if what.is_a?(Bliftax::Implicant)

      cost_sum = what.size
      cost_sum += what.to_a.reduce(0) { |a, e| a + e.cost }
      cost_sum
    end

    # Finds the minimum-cost combination to cover the given minterms.
    # This method does recursive DFS to search for the minimum-cost
    # combination, so it may become slow depending on the number of available
    # options.
    #
    # @param to_cover [Set<Integer>] the set of minterms that need to be
    #   covered.
    # @param options [Set<Implicant>] the set of implicants to choose from.
    #
    # @return [Set<Implicant>] a set of implicants that has achieves the cover
    #   in the minimum cost.
    def branching(to_cover, options)
      to_use = Set.new
      options.dup.each do |implicant|
        result = branching_helper(to_cover, options, implicant)
        if result.include?(implicant)
          to_use.add(implicant)
          to_cover -= implicant.minterms
          options.delete(implicant)
        end
      end
      to_use
    end

    private

    module_function

    # A helper method for the recursive DFS for branching heuristic.
    #
    # @param to_cover [Set<Integer>] minterms that need to be covered.
    # @param options [Set<Implicant>] the prime implicants that we can choose
    #   from.
    # @param implicant [Implicant] the implicant that's being decided whether
    #   to include in the final cover or not.
    # @return the set that results in a better cost when including or not
    #   including the implicant.
    def branching_helper(to_cover, options, implicant)
      # Get implicants from options that cover at least one required vertex
      options = options.select do |o|
        !(to_cover & o.minterms).empty?
      end
      options = options.to_set

      # Base case
      return Set.new if options.empty?

      # Final cover when using the implicant
      new_options = options - Set.new([implicant])
      using_implicant = branching_helper(to_cover - implicant.minterms,
                                         new_options,
                                         new_options.to_a.first)
      # Don't forget to add this implicant
      using_implicant.add(implicant)
      # Final cover when not using the implicant
      not_using_implicant = branching_helper(to_cover,
                                             new_options,
                                             new_options.to_a.first)

      cost_using = cost(using_implicant)
      cost_not_using = cost(not_using_implicant)

      # Not using this implicant results in as good a coverage but less cost
      minterms_coverage = not_using_implicant.map(&:minterms).to_set.flatten
      if cost_not_using < cost_using && minterms_coverage >= to_cover
        return not_using_implicant
      end
      return using_implicant
    end
  end
end
