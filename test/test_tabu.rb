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

    should "update a distribution" do
      @d.update(4, 2)
      assert_equal @d.mean, 4
      assert_equal @d.sd, 2
    end

    should "update a distribution with malformed data" do
      assert_raise RuntimeError do
        @d.update(nil, 2)
      end
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

    should "loosen a distribution all the way" do
      n = 0 # to stop possible infinite loops
      while !@d.loosen && n < 100
        n += 1
      end
      assert_equal @d.loosen, true
    end

    should "reduce sd to the minimum" do
      @d.set_sd_to_min
      assert_equal @d.sd, 0.5
    end

    should "set sd to the maximum" do
      @d.set_sd_to_max
      assert_equal @d.sd.round(5), 7.26000
    end

    should "draw from distribution" do
      sum = 0.0
      sd = 0.0
      1000.times do
        v = @d.draw
        sd += (v - @d.mean)**2
        sum += @range[v]
        assert @range[v]
      end
      sum /= 1000.0 # should be close to dist.mean
      sd /= 1000.0
      sd = Math.sqrt(sd)
      assert_equal sum.round, @range[@d.mean], "mean"
      assert_equal sum.round, @range[@d.dist.get_mean], "mean 2"
      assert_equal sd.round(0), @d.dist.get_standard_deviation, "sd"
    end

    should "fail with malformed arguments" do
      assert_raise RuntimeError do
        d = Biopsy::Distribution.new(nil, @range, 0.1, 1)
      end
    end

  end # Distribution context

  context "Hood" do

    setup do
      range1 = [7,8,9,10,11,12,13]
      range2 = [50,100,150,200,250,300]
      ranges = {:a => range1, :b => range2}
      centre = {:parameters => {:a => 3, :b => 2}, :score => 0.1}
      @sd = 0.5
      inc = 0.05
      size = 5
      @hood = Biopsy::Hood.new(centre, ranges, size, @sd, inc, Set.new)
    end

    teardown do
    end

    should "create a hood with neighbours" do
      assert @hood
      assert_equal @hood.neighbours.size, 5
      assert_equal @hood.tabu.size, 5
    end

    should "check that the means are inside the range" do
      range1 = [7,8,9,10,11,12,13]
      range2 = [50,100,150,200,250,300]
      ranges = {:a => range1, :b => range2}
      centre = {:parameters => {:a => 3, :b => 100}, :score => 0.1}
      @sd = 0.5
      inc = 0.05
      size = 5
      assert_raise RuntimeError do
        hood = Biopsy::Hood.new(centre, ranges, size, @sd, inc, Set.new)
      end
    end

    should "get the next neighbour from a hood" do
      neighbour = @hood.next
      assert neighbour
      assert_equal neighbour.size, 2 # 2 parameters
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
      new_score = {:parameters => {:a => 2, :b => 3}, :score => 0.2}
      assert_equal @hood.update_best?(new_score), true
      assert_equal @hood.best[:score], 0.2
      assert_equal @hood.best[:parameters][:a], 2
      assert_equal @hood.best[:parameters][:b], 3

      new_score = {:parameters => {:a => 2, :b => 2}, :score => 0.3}
      assert_equal @hood.update_best?(new_score), true
      assert_equal @hood.best[:score], 0.3
      assert_equal @hood.best[:parameters][:a], 2
      assert_equal @hood.best[:parameters][:b], 2
    end

    should "not update the best score because this one is worse" do
      new_score = {:parameters => {:a => 6, :b => 4}, :score => 0.01}
      @hood.update_best? new_score
      assert_equal @hood.best[:score], nil
      assert_equal @hood.best[:parameters], nil
    end

    # should "loosen distribution if can't make more neighbours" do
    #   count=0
    #   while @hood.neighbours.size==5
    #     @hood.generate_neighbour
    #   end
    #   assert @hood.distributions[:a].sd > @sd, 
    # end

    should "set the centre to a new centre" do
      centre = {:parameters => {:a => 2, :b => 1}, :score => 0.2}
      @hood.set_new_centre centre
      @hood.distributions.each_pair do |key, dist|
        assert_equal dist.mean, centre[:parameters][key]
      end
    end

    should "fail on malformed centre" do
      hash = {:parameters => {:a => 2}}
      assert_raise RuntimeError do
        @hood.set_new_centre hash
      end
    end

  end # Hood context

  context "Tabu Thread" do
    setup do
      @ranges = {:a => [7,8,9,10,11,12,13], :b => [50,100,150,200,250,300]}
      @start = {:parameters => {:a => 3, :b => 2}, :score => 0.1}
      @tabu_thread = Biopsy::TabuThread.new(@ranges, @start)
    end

    should "create a tabu thread object" do
      assert @tabu_thread
    end

    should "contain a hood object" do
      h = @tabu_thread.hood
      assert h
      assert_equal h.best[:score], nil
      assert_equal h.distributions.size, 2
    end

    should "return a new candidate set of parameters" do
      candidate = @tabu_thread.next_candidate
      assert candidate
      assert_equal candidate[:parameters].size, 2
      assert_equal candidate[:score], nil
    end

    should "add result" do
      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate[:parameters], 0.4
      # should update the best with the new result
      assert_equal @tabu_thread.best[:score], 0.4
      # should put the new result into the best history
      assert_equal @tabu_thread.best_history.size, 1

      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate[:parameters], 0.2
      # the best score should still be the same
      assert_equal @tabu_thread.best[:score], 0.4
      # nothing new should have been added to the best history
      assert_equal @tabu_thread.best_history.size, 1
    end

    # should "do something sensible when you ask for the next candidate "+
    #        "but there aren't any" do
    #   assert nil, 'not yet implemented'
    # end

    should "generate a new list of neighbours when previous neighhours "+
           "were not any better" do
      fudge_best = {:parameters => {:a => 1, :b => 3}, :score => 0.1}
      # mark the best as a non-nil score so new scores can be below it
      @tabu_thread.best = fudge_best
      list = @tabu_thread.hood.neighbours.clone
      assert_equal list.size, 5
      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate[:parameters], 0.0
      list2 = @tabu_thread.hood.neighbours.clone
      # list2 should contain no items from list1
      list2.each do |n|
        assert_equal list.include?(n), false
      end
    end

    should "move the centre of the hood when new best is found" do
      assert_equal @tabu_thread.hood.neighbours.size, 5,
        "neighbourhood size is #{@tabu_thread.hood.neighbours.size}, should "+
        "be 5"
      best_candidate = @tabu_thread.next_candidate # 1
      @tabu_thread.add_result best_candidate[:parameters], 1.0
      candidate = @tabu_thread.next_candidate # 2
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate # 3
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate # 4
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate # 5
      @tabu_thread.add_result candidate[:parameters], 0.0
      candidate = @tabu_thread.next_candidate # 6
      assert @tabu_thread.hood.neighbours.size > 0
        "new neighbourhood size is #{@tabu_thread.hood.neighbours.size}, "+
        "should be 5"
      assert_equal @tabu_thread.hood.centre, best_candidate, 
        "best candidate #{best_candidate} should equal new "+
        "centre #{@tabu_thread.hood.centre}"
    end

  end

  # context "Tabu Search" do

  #   setup do
  #     @ranges = {:a => [0,1,2,3,4,5,6], :b => [50,100,150,200,250,300]}
  #     @tabu_search = Biopsy::TabuSearch.new(@ranges, 1, 0)
  #   end

  #   teardown do
  #   end

  #   should "create a TabuSearch object" do
  #     assert @tabu_search
  #   end

  #   should "set up threads" do
  #     @tabu_search.setup_threads
  #     assert_equal @tabu_search.threads.length, 5
  #   end

  # end

end # TestTabu class
