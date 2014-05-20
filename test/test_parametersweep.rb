require 'helper'

class TestParameterSweeper < Test::Unit::TestCase

  context "ParameterSweeper" do

    setup do
      ranges = {:a => [1,2,3], :b => [1,2,3]}
      @sweep = Biopsy::ParameterSweeper.new(ranges)
      @sweep.setup
    end

    should "calculate number of combinations" do
      c = @sweep.combinations
      assert_equal c, 9
    end

    should 'generate list of combinations' do
      list=[]
      9.times do
        list << @sweep.next
      end
      assert_equal list, [{:a=>1, :b=>1}, {:a=>1, :b=>2}, {:a=>1, :b=>3},
       {:a=>2, :b=>1}, {:a=>2, :b=>2}, {:a=>2, :b=>3}, 
       {:a=>3, :b=>1}, {:a=>3, :b=>2}, {:a=>3, :b=>3}]
    end

    should "exit gracefully when you ask for too much" do
      c = 1
      10.times do
        c = @sweep.run_one_iteration(nil, 0)
      end
      assert_equal c, nil
    end

    should 'check if finished' do
      assert_equal @sweep.finished?, false, "at the start"
      8.times do
        @sweep.run_one_iteration(nil, 0)
      end
      assert_equal @sweep.finished?, false, "after 8"
      @sweep.run_one_iteration(nil, 0)
      assert_equal @sweep.finished?, false, "after 9"
      @sweep.run_one_iteration(nil, 0)
      assert_equal @sweep.finished?, true, "after 10"
    end

    should 'find the maximum in a complex function' do
      def sinusoidal(ranges, params)
        return if params.size != 3
        a = ranges[:a][params[:a].to_i]
        b = ranges[:b][params[:b].to_i]
        c = ranges[:c][params[:c].to_i]
        value = Math.cos(a) + Math.cos(b) - (a/10.0)**2 - (b/10.0)**2 - (c/20.0)**2
        return value
      end

      ranges = { :a => (-10..20).to_a,
                 :b => (-10..20).to_a,
                 :c => (-10..20).to_a }

      sweep = Biopsy::ParameterSweeper.new(ranges)
      sweep.setup

      p = sweep.next
      while p != nil
        a = sinusoidal(ranges, p)
        p = sweep.run_one_iteration(p, a)
      end
      assert_equal sweep.best[:parameters][:a], 10
      assert_equal sweep.best[:parameters][:b], 10
      assert_equal sweep.best[:parameters][:c], 10
      assert_equal sweep.best[:score], 2.0
    end


  end # Experiment context

end # TestExperiment
