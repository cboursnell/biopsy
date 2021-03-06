

# Assembly Optimisation Framework: Objective Function
# 
# == Description
# 
# ObjectiveFunction is a skeleton parent class to ensure
# objective functions provide the essential methods.
# Because abstract classes don't really make sense in
# Ruby's runtime compilation, we can only check if methods
# are implemented at runtime (but at least we can raise
# a sensible error)
module Biopsy

  class ObjectiveFunction

    # Runs the objective function for the assembly supplied,
      # returning a real number value
      #
      # === Options
      #
      # * +:assemblydata+ - Hash containing data about the assembly to analyse
      #
      # === Example
      #
      # objective = ObjectiveFunction.new
      # result = objective.run('example.fasta')
    def run(raw_output, output_files, threads)
      raise NotImplementedError.new("You must implement a run method for each objective function")
    end

    def essential_files
      return []
    end

  end
  
end