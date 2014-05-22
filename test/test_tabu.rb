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
      assert_equal @d.loosen, true
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

    should "truncate the normal distribution" do
      range = [2, 4, 6, 8, 10, 12, 14, 16, 18]
      d = Biopsy::Distribution.new(4, range, 0.1, 100)
      100.times do
        r = d.draw
        assert r >= 0, "r is #{r} r < 0"
        assert r < range.size, "r is #{r}, r >= range.size"
      end
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
      @centre = {:parameters => {:a => 3, :b => 2}, :score => 0.1}
      @sd = 0.5
      inc = 0.05
      size = 5
      @hood = Biopsy::Hood.new(@centre, ranges, size, @sd, inc, Set.new)
    end

    teardown do
      @hood=nil
    end

    should "add the centre to the tabu list "+
           "when the score of centre is nil" do
      range1 = [7,8,9,10,11,12,13]
      range2 = [50,100,150,200,250,300]
      ranges = {:a => range1, :b => range2}
      centre = {:parameters => {:a => 3, :b => 2}, :score => nil}
      inc = 0.05
      size = 5
      hood = Biopsy::Hood.new(centre, ranges, size, @sd, inc, Set.new)
      assert_equal hood.neighbours.size, 5,
          "size should be 5, but is #{hood.neighbours.size}"
      assert hood.tabu.member?(centre[:parameters])
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
      assert_equal @hood.update_best?(new_score), false
      assert_equal @hood.best[:score], nil
      assert_equal @hood.best[:parameters], nil
    end

    should "loosen distribution if can't make more neighbours" do
      assert_equal @hood.distributions[:a].sd, @sd,
          "#{@hood.distributions[:a].sd} should equal #{@sd} but it doesn't"
      assert_equal @hood.distributions[:b].sd, @sd,
          "#{@hood.distributions[:b].sd} should equal #{@sd} but it doesn't"
      f = 0
      count = 0
      while f == 0 && count < 15
        f = @hood.populate
        count += 1
      end
      assert f > 0
      assert @hood.distributions[:a].sd > @sd
      assert @hood.distributions[:b].sd > @sd
    end

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
      @start = {:a => 3, :b => 2}
      @tabu_thread = Biopsy::TabuThread.new(@ranges, @start)
    end

    should "create a tabu thread object" do
      assert @tabu_thread
      assert_equal @tabu_thread.current, {:parameters => @start, :score => nil}
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
      assert_equal candidate.size, 2
    end

    should "add result" do
      # add a score for the centre
      @tabu_thread.add_result @start, 0.4
      # should update the best with the new result
      assert_equal @tabu_thread.best[:score], 0.4
      # should put the new result into the best history
      assert_equal @tabu_thread.best_history.size, 1,
          "best history should be length 1, "+
          "it is #{@tabu_thread.best_history.size}"
      candidate = @tabu_thread.next_candidate
      assert candidate[:a], "candidate should be just parameters no score"
      @tabu_thread.add_result candidate, 0.3
      assert_equal @tabu_thread.best_history.size, 1

      candidate = @tabu_thread.next_candidate
      @tabu_thread.add_result candidate, 0.2
      # the best score should still be the same
      assert_equal @tabu_thread.best[:score], 0.4
      # nothing new should have been added to the best history
      assert_equal @tabu_thread.best_history.size, 1
    end

    should "add a result and update the score of the centre of the hood" do
      @tabu_thread.add_result @start, 0.2
      assert_equal @tabu_thread.hood.centre[:score], 0.2
    end

    should "generate new list of neighbours when previous neighhours "+
           "not any better" do
      @tabu_thread.add_result @start, 0.1 # this scores the centre

      assert_equal @tabu_thread.hood.best[:score], 0.1

      assert_equal @tabu_thread.hood.neighbours.size, 5,
      "there should be 5 neighbours in the list at the start"

      # draw 5 candidates from the hood. all will be scored badly.
      5.times do
        candidate = @tabu_thread.next_candidate
        @tabu_thread.add_result candidate, 0.0
      end

      # check that the neighbourhood is empty
      assert_equal @tabu_thread.hood.neighbours.size, 0,
      "there should be 0 neighbours in the list now"

      # should draw another candidate
      candidate = @tabu_thread.next_candidate

      # there should at least be 1 new neighbour in the hood yo
      assert @tabu_thread.hood.neighbours.size > 0
    end

    should "move the centre of the hood when new best is found" do
      assert_equal @tabu_thread.hood.neighbours.size, 5,
        "neighbourhood size is #{@tabu_thread.hood.neighbours.size}, should "+
        "be 5"

      @tabu_thread.add_result @start, 0.0 # scoring the centre first

      best_candidate = @tabu_thread.next_candidate # 1
      @tabu_thread.add_result best_candidate, 1.0

      candidate = @tabu_thread.next_candidate # 2
      @tabu_thread.add_result candidate, 0.0

      candidate = @tabu_thread.next_candidate # 3
      @tabu_thread.add_result candidate, 0.0

      candidate = @tabu_thread.next_candidate # 4
      @tabu_thread.add_result candidate, 0.0

      candidate = @tabu_thread.next_candidate # 5
      @tabu_thread.add_result candidate, 0.0

      candidate = @tabu_thread.next_candidate # this pulls 
      
      assert @tabu_thread.hood.neighbours.size > 0,
        "new neighbourhood size is #{@tabu_thread.hood.neighbours.size}, "+
        "should be 5"

      assert_equal @tabu_thread.hood.centre[:parameters], best_candidate, 
        "best candidate #{best_candidate} should equal new "+
        "centre #{@tabu_thread.hood.centre[:parameters]}"
    end

  end # context Tabu Thread

  context "Tabu Search" do

    setup do
      @ranges = {:a => [0,1,2,3,4,5,6], :b => [50,100,150,200,250,300]}
      @tabu_search = Biopsy::TabuSearch.new(@ranges,5)
    end

    teardown do
    end

    should "create a TabuSearch object" do
      assert @tabu_search
    end

    should "set up threads" do
      start = {:a => 0, :b => 0}
      @tabu_search.setup start
      assert_equal @tabu_search.threads.length, 5,
       "found #{@tabu_search.threads.length}"
    end

    should "take results and return next candidate" do
    end

    should "process each thread in turn" do
    end

    should "run one iteration" do
      start = {:a => 0, :b => 0}
      @tabu_search.setup_threads start
      # target.run goes here and returns raw output
      # the raw output is parsed to give a result
      params = {:a => 0, :b => 0}
      result = 1.0
      new_params = @tabu_search.run_one_iteration(params, result)
      new_params.each_pair do |k, v|
        assert params[k]
      end
    end

    should "check this quadratic function works ok" do
      ranges = { :a => (-10..10).to_a, 
                 :b => (-10..10).to_a, 
                 :c => (-10..10).to_a }
      params = {:a => 14, :b => 14, :c => 14}
      assert_equal Helper.quadratic(ranges, params), 0
      params = {:a => 10, :b => 10, :c => 10}
      assert_equal Helper.quadratic(ranges, params), -12
    end

    should "find the maximum of a simple quadratic" do

      ranges = { :a => (-10..10).to_a, 
                 :b => (-10..10).to_a, 
                 :c => (-10..10).to_a }

      search = Biopsy::TabuSearch.new(ranges,1)
      start = {:a=>10, :b=>10, :c=>8}
      current = start
      search.setup(start)
      # do target.run
      130.times do
        result = Helper.quadratic(ranges, current)
        #puts "current = #{current}, result = #{result}"
        current = search.run_one_iteration(current, result)
      end
      
      assert_equal search.threads[0].best[:parameters][:a], 14
      assert_equal search.threads[0].best[:parameters][:b], 14
      assert_equal search.threads[0].best[:parameters][:c], 14
    end

    should "find the maximum in a more complex function" do
      ranges = { :a => (-10..20).to_a, 
                 :b => (-10..20).to_a, 
                 :c => (-10..20).to_a }

      search = Biopsy::TabuSearch.new(ranges, 1)
      start = { :a => 23, :b => 23, :c => 23 }
      current = start
      search.setup(start)
      # do target.run
      best_at = -1
      2000.times do |i|
        result = Helper.sinusoidal(ranges, current)
        best_at = i if result == 2.0
        # puts "#{i}\tcurrent = #{current}, result = #{result}"
        current = search.run_one_iteration(current, result)
      end
      assert_equal search.threads[0].best[:score], 2.0
      assert_equal search.threads[0].best[:parameters][:a], 10
      assert_equal search.threads[0].best[:parameters][:b], 10
      assert_equal search.threads[0].best[:parameters][:c], 10
      puts "best found at #{best_at}"
    end

    should "be able to specify multiple start locations" do
      ranges = { :a => (-10..20).to_a, 
                 :b => (-10..20).to_a, 
                 :c => (-10..20).to_a }

      search = Biopsy::TabuSearch.new(ranges, 3)
      start = []
      start << { :a => 23, :b => 23, :c => 23 }
      start << { :a => 5, :b => 3, :c => 2 }
      start << { :a => 20, :b => 5, :c => 20 }
      current = start[0]
      search.setup(start)
      assert_equal search.threads.length, 3
      assert search.threads[0].hood, "centre is nil"
      assert_equal search.threads[0].hood.centre[:parameters][:a], 23
      assert_equal search.threads[0].hood.centre[:parameters][:b], 23
      assert_equal search.threads[0].hood.centre[:parameters][:c], 23
      assert_equal search.threads[1].hood.centre[:parameters][:a], 5
      assert_equal search.threads[1].hood.centre[:parameters][:b], 3
      assert_equal search.threads[1].hood.centre[:parameters][:c], 2
      assert_equal search.threads[2].hood.centre[:parameters][:a], 20
      assert_equal search.threads[2].hood.centre[:parameters][:b], 5
      assert_equal search.threads[2].hood.centre[:parameters][:c], 20
    end

    should "get multiple threads to converge" do
      ranges = { :a => (-10..20).to_a, 
                 :b => (-10..20).to_a, 
                 :c => (-10..20).to_a }

      search = Biopsy::TabuSearch.new(ranges, 3)
      start = []
      start << { :a => 23, :b => 23, :c => 23 }
      start << { :a => 5, :b => 3, :c => 2 }
      start << { :a => 20, :b => 5, :c => 20 }
      search.setup(start)

      current = search.threads[0].current[:parameters]
      4000.times do |i|
        result = Helper.sinusoidal(ranges, current)
        # puts "<Test> got score #{result} from #{current}"
        current = search.run_one_iteration(current, result)
      end
      assert_equal search.threads[0].best[:score], 2.0
      assert_equal search.threads[0].best[:parameters][:a], 10
      assert_equal search.threads[0].best[:parameters][:b], 10
      assert_equal search.threads[0].best[:parameters][:c], 10
      assert_equal search.threads[1].best[:score], 2.0
      assert_equal search.threads[1].best[:parameters][:a], 10
      assert_equal search.threads[1].best[:parameters][:b], 10
      assert_equal search.threads[1].best[:parameters][:c], 10
      assert_equal search.threads[2].best[:score], 2.0
      assert_equal search.threads[2].best[:parameters][:a], 10
      assert_equal search.threads[2].best[:parameters][:b], 10
      assert_equal search.threads[2].best[:parameters][:c], 10
    end

    should "stop when criteria are met" do
      ranges = { :a => (-10..20).to_a, 
                 :b => (-10..20).to_a, 
                 :c => (-10..20).to_a }

      search = Biopsy::TabuSearch.new(ranges, 3)
      start = []
      start << { :a => 23, :b => 23, :c => 23 }
      start << { :a => 5, :b => 3, :c => 2 }
      start << { :a => 20, :b => 5, :c => 20 }
      search.setup(start)

      current = search.threads[0].current[:parameters]
      i=10000
      while !search.finished? and i>0
        result = Helper.sinusoidal(ranges, current)
        # puts "<Test> got score #{result} from #{current}"
        current = search.run_one_iteration(current, result)
        i -= 1
      end
      assert i > 0, "didn't finish in time. used up all iterations"
      assert_equal search.threads[0].best[:score], 2.0
      assert_equal search.threads[0].best[:parameters][:a], 10
      assert_equal search.threads[0].best[:parameters][:b], 10
      assert_equal search.threads[0].best[:parameters][:c], 10
      assert_equal search.threads[1].best[:score], 2.0
      assert_equal search.threads[1].best[:parameters][:a], 10
      assert_equal search.threads[1].best[:parameters][:b], 10
      assert_equal search.threads[1].best[:parameters][:c], 10
      assert_equal search.threads[2].best[:score], 2.0
      assert_equal search.threads[2].best[:parameters][:a], 10
      assert_equal search.threads[2].best[:parameters][:b], 10
      assert_equal search.threads[2].best[:parameters][:c], 10
    end

  end

end # TestTabu class
