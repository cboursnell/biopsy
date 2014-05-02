require 'rubystats'
require 'statsample'
require 'set'
require 'pp'
require 'matrix'

# TODO:
# - make distributions draw elements from the range, not just from 
#       distribution (DONE)
# - test on real SOAPdt data (in progress)
# - make code to run 100 times for a particular dataset, capture the 
#       trajectory, and plot the progress over time along with a histogram 
#       of the data distribution
# - plot SD and step-size over time
# - capture data about convergence (done for toy data, need to repeat for 
#       other data)

module Biopsy

  # a Distribution represents the probability distribution from
  # which the next value of a parameter is drawn. The set of all
  # distributions acts as a probabilistic neighbourhood structure.
  class Distribution

    attr_accessor :sd, :mean, :maxsd, :minsd, :dist

    # create a new Distribution
    def initialize(mean, range, sd_increment_proportion, sd)
      @mean = mean # index in range
      @maxsd = range.size * 0.66
      @minsd = 0.5
      @sd = sd
      self.limit_sd
      @range = range
      @sd_increment_proportion = sd_increment_proportion
      self.generate_distribution @mean, @sd
    end

    # generate the distribution
    def generate_distribution mean, sd
      unless mean && sd
        raise RuntimeError, "generation of distribution with "+
                            "mean: #{mean}, sd: #{sd} failed."
      end
      @dist = Rubystats::NormalDistribution.new(mean, sd)
    end

    def update mean, sd
      unless mean && sd
        raise RuntimeError, "generation of distribution with "+
                            "mean: #{mean}, sd: #{sd} failed."
      end
      @mean = mean
      @sd = sd
      @dist = Rubystats::NormalDistribution.new(mean, sd)
    end

    def limit_sd
      @sd = @sd > @maxsd ? @maxsd : @sd
      @sd = @sd < @minsd ? @minsd : @sd
    end

    # loosen the distribution by increasing the sd
    # and regenerating
    def loosen(factor:1)
      can_loosen = @sd < @maxsd
      @sd += @sd_increment_proportion * factor * @range.size
      self.limit_sd
      self.generate_distribution @mean, @sd
      can_loosen
    end

    # tighten the distribution by reducing the sd
    # and regenerating
    def tighten(factor:1)
      @sd -= @sd_increment_proportion * factor * @range.size if @sd > 0.01
      self.limit_sd
      self.generate_distribution @mean, @sd
      @sd == @minsd # is this as tight as it can be made?
    end

    # set standard deviation to the minimum possible value
    def set_sd_to_min
      @sd = @minsd
    end

    def set_sd_to_max
      @sd = @maxsd
    end

    # draw from the distribution
    def draw
      r = @dist.rng.round.to_i # r is an index into range
      unless r.is_a? Integer
        raise RuntimeError, "drawn number must be an integer"
      end
      # keep the value inside the allowed range
      while r < 0 || r >= @range.size
        if r < 0
          r = 0 - r
        elsif r >= @range.size
          r = 2 * @range.size - 1 - r
        end
      end
      r
    end

  end # Distribution

  # a Hood represents the neighbourhood of a specific location
  # in the parameter space being explored. It is generated using
  # the set of Distributions, which together define the neighbourhood
  # structure.
  class Hood

    attr_reader :centre, :best, :tabu, :neighbours, :distributions, :size

    def initialize(centre, ranges, size, sd, increment, tabu)
      @centre = centre
      @ranges = ranges
      @centre[:parameters].each_pair do |key, value|
        if value < 0 || value >= @ranges[key].size
          raise RuntimeError, "value #{value} is not an index to range #{key}"
        end
      end
      # tabu
      @tabu = tabu 
      # neighbourhood
      @size = size # number of neighbours that will be created
      @neighbours = []
      @best = {
        :parameters => nil,
        :score => nil
      }
      # probabilities
      @sd = sd
      @distributions = {}
      ranges.each_pair do |key, list|
        @distributions[key] = Biopsy::Distribution.new(
                                centre[:parameters][key], list, increment, @sd)
      end
      @give_up = 50
      self.populate
    end

    # generate a single neighbour
    def generate_neighbour
      n = 0
      can_loosen=true
      begin
        if n >= @give_up
          # taking too long to generate a neighbour, 
          # loosen the neighbourhood structure so we explore further
          # debug("loosening distributions")
          @distributions.each do |param, dist|
            # if this is already as loose as it can go, then stop
            # loosening and really give up and tell the caller you can't
            # generate any more neighbours
            can_loosen = dist.loosen
            n = 0 # if you don't set this back to zero you'll keep loosening
                  # repeatedly until you get a non-tabu neighbour
          end
        end
        # preform the probabilistic step move for each parameter
        neighbour = Hash[ @distributions.map { |param, dist| [param, dist.draw] }]
        n += 1
      end while self.is_tabu?(neighbour) && can_loosen
      if is_tabu?(neighbour)
        return false
      else
        @tabu << neighbour
        @neighbours << neighbour
        return true
      end
    end

    def set_new_centre centre
      unless centre[:parameters] && centre[:score]
        raise RuntimeError, "centre has wrong parameters" 
      end
      @centre = centre
      @distributions.each_pair do |key, dist|
        dist.update centre[:parameters][key], @sd
      end
    end

    # update best?
    def update_best? new_result
      # check new results parameters are inside each range, ie sanity check
      new_result[:parameters].each_pair do |key, value|
        if value < 0 || value >= @ranges[key].size
          raise RuntimeError, "value #{value} is not an index to range #{key}"
        end
      end
      # update if new is better than old
      better = false
      if new_result[:parameters]==@centre[:parameters] && @centre[:score].nil?
        @best = new_result.clone
        @centre[:score] = new_result[:score]
        better = true
      else
        if @centre[:score].nil? || new_result[:score] > @centre[:score]
          if @best[:score].nil? || new_result[:score] > @best[:score]
            @best = new_result.clone
            better = true
          end
        end
      end
      better
    end

    # true if location is tabu
    def is_tabu? location
      @tabu.member? location
    end

    # generate the population of neighbours
    def populate
      fails=0
      @size.times do |i|
        if !self.generate_neighbour
          fails += 1
          # neighbour generation failed          
        end
      end
      if fails > 0
        # maybe do something about this?
        # do some backtracking
        # and if that fails or can't be done then
        # add random non-tabu items from the population to the neighbours
        # Hash[@ranges.map { |p, r| [p, r.sample] }] 
        #
      end
    end

    # return the next neighbour from this Hood
    def next
      @neighbours.pop
    end

    # returns true if the current neighbour is
    # the last one in the Hood
    def last?
      @neighbours.empty?
    end

  end # Hood


  class TabuThread

    attr_accessor :current       # the current set of parameters - needed?
    attr_accessor :best          # the best parameters and score found so far
    attr_accessor :distributions # a hash of Distributions with the parameter 
                                 #   as the key
    attr_accessor :tabu          # a set of previous parameters that have been
                                 # explored/scored
    attr_accessor :recent        # a list of recent parameters and scores
    attr_accessor :best_history  # a list of best parameters and scores
    attr_accessor :hood          # the current hood

    def initialize parameter_ranges, start
      @best = {:parameters => nil, :score => nil}
      @recent = []
      @best_history = []
      @tabu = Set.new # this could be global. but then different threads
                      # couldn't converge
      sd = 0.5
      hood_size = Biopsy::TabuSearch.hood_size
      sd_inc = Biopsy::TabuSearch::sd_increment_proportion
      @centre = start
      @hood = Hood.new(@centre, parameter_ranges, hood_size, sd, sd_inc, @tabu)
    end

    # get the next neighbour to explore from the current hood
    def next_candidate
      if @hood.last?
        if @best[:score] && @best[:score] > @centre[:score]
          # update the centre
          @hood.set_new_centre @best
        end
        # make more neighbours from the current centre
        @hood.populate
      end
      @current = {:parameters => @hood.next, :score => nil}
    end

    def add_result params, result
      # check that the parameters i'm getting back are the ones i sent out
      if params == @current[:parameters]
        @current[:score] = result
      end
      if @hood.update_best? @current
        @best = @current
        @best_history << @current
      end
    end
  end

  # A Tabu Search implementation with a domain-specific probabilistic
  # learning heuristic for optimising over an unconstrained parameter
  # space with costly objective evaluation.
  class TabuSearch #< OptmisationAlgorithm

    @@sd_increment_proportion = 0.05
    @@hood_size = 5

    def initialize parameter_ranges, threads
      @ranges = parameter_ranges
      @num_threads = threads
      @threads = []
      @current_thread = 0
      @total_number_of_iterations = 0
    end

    def setup start
      self.setup_threads start
    end

    def setup_threads start
      # the first thread starts at the specified start point
      @threads << TabuThread.new(@ranges, start)
      (@num_threads-1).times do
        # the remaining threads start at a random point
        @threads << TabuThread.new(@ranges, self.random_start_point)
      end
    end

    # experiment used these params to get this result
    #
    # take the result and pass it to the current thread
    #
    # return a new set of parameters to experiment
    def run_one_iteration(params, result)
      raise RuntimeError, "haven't made any threads yet" if @threads.size==0
      @total_number_of_iterations += 1
      @threads[@current_thread].add_result(params, result)
      @current_thread = (@current_thread + 1) % @num_threads
      @threads[@current_thread].next_candidate
    end

    # class methods
    def self.sd_increment_proportion
      @@sd_increment_proportion
    end

    def self.hood_size
      @@hood_size
    end

    def knows_starting_point?
      true
    end

    def select_starting_point
      self.random_start_point
    end

    def random_start_point
      Hash[@ranges.map { |p, r| [p, r.index(r.sample)] }] 
    end

    def finished?
      return true if @total_number_of_iterations > 100
    end

    def write_data
    end
  end

end # Biopsy
