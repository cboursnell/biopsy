require 'helper'

class TestTabu < Test::Unit::TestCase

  require 'fileutils'

  context "Distribution" do

    setup do
      @range = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
      # the mean of the distribution is the index in the range
      @d = Biopsy::Distribution.new(5, @range, 0.1, 1)
    end

    teardown do
    end

    should "create a distribution" do
      assert @d
      assert_equal @d.mean, 5
      assert_equal @d.maxsd.round(5), 7.26000
      assert_equal @d.minsd, 0.50
    end

    should "limit the standard deviation" do
      range = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
      d = Biopsy::Distribution.new(5, range, 0.1, 100)
      assert d
      assert_equal d.sd, d.maxsd
    end

    should "generate a normal distribution" do
      assert_equal @d.dist.get_standard_deviation, 1 
      assert_equal @d.dist.get_mean, 5
      assert_equal @d.dist.get_variance, 1
    end

    should "loosen distribution" do
      @d.loosen
      assert_equal @d.sd, 2.1
    end

    should "tighten distribution" do
      @d.tighten
      assert_equal @d.sd, 0.5
      assert_equal @d.dist.get_standard_deviation, 0.5
    end

    should "reduce sd to the minimum" do
      @d.set_sd_min
      assert_equal @d.sd, 0.5
    end

    should "draw from distribution" do
      sum = 0.0
      sd = 0.0
      1000.times do
        v = @d.draw
        sd += (@range.index(v)-@d.mean)**2
        sum += v
        assert @range.include?(v)
      end
      sum /= 1000.0 # should be close to dist.mean
      sd /= 1000.0
      sd = Math.sqrt(sd)
      assert_equal sum.round, @range[@d.mean]
      assert_equal sum.round, @range[@d.dist.get_mean]
      assert_equal sd.round(0), @d.dist.get_standard_deviation
    end

  end # Distribution context

  context "Hood" do

    setup do
      range1 = [0,1,2,3,4,5,6]
      range2 = [50,100,150,200,250,300]
      d1 = Biopsy::Distribution.new(3, range1, 0.05, 0.5)
      d2 = Biopsy::Distribution.new(2, range2, 0.05, 0.5)
      hash = {:a => d1, :b => d2}
      @hood = Biopsy::Hood.new(hash, 5, Set.new)
    end

    teardown do
    end

    should "create a hood with neighbours" do
      assert @hood
      assert_equal @hood.members.size, 5
      assert_equal @hood.tabu.size, 5
    end

    should "get the next neighbour from a hood" do
      neighbour = @hood.next
      assert neighbour
      assert_equal neighbour.size, 2
    end

    should "check if there are no neighbours left" do
      assert @hood.next
      assert @hood.next
      assert @hood.next
      assert @hood.next
      assert @hood.next
      assert @hood.last?
    end

    should "update the best score" do
      current = {:parameters => {:a => 2, :b => 250}, :score => 10}
      @hood.update_best? current
      assert_equal @hood.best[:score], 10
      assert_equal @hood.best[:parameters][:a], 2
      assert_equal @hood.best[:parameters][:b], 250
    end

    should "loosen distribution if can't make more neighbours" do
      count=0
      while count < 20
        @hood.generate_neighbour
        count +=1
      end
      assert @hood.distributions[:a].sd!=0.5
    end

  end # Hood context

  context "Tabu Search" do

    setup do
      @ranges = {:a => [0,1,2,3,4,5,6], :b => [50,100,150,200,250,300]}
      @tabu_search = Biopsy::TabuSearch.new(@ranges, 1, 0)
    end

    teardown do
    end

    should "create a TabuSearch object" do
      assert @tabu_search
    end

    should "set up threads" do
      @tabu_search.setup_threads
      assert_equal @tabu_search.threads.length, 5
    end

  end

end # TestTabu class