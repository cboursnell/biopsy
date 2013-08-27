module Biopsy

  class TargetLoadError < Exception
  end

  class Target
    require 'yaml'
    require 'ostruct'

    # array of input files expected by the target constructor
    attr_reader :input_files
    # array of output files to keep for submission to objective
    # functions during optimisation
    attr_reader :output_files
    # hash mapping parameters to the ranges of values they can take
    attr_reader :parameter_ranges
    # path to the constructor code
    attr_reader :constructor_path

    # create a new Target instance.
    # arguments:
    # +:domain+ the domain to which this target belongs (see Domain documentation)
    def initialize domain
      @domain = domain
    end

    # load target with +name+.
    def load_by_name name
      @config_path = self.locate_definition name
      config = YAML::load_file(@config_path).deep_symbolize
      missing = self.check_config config
      if missing
        raise TargetLoadError.new("The target definition at #{@config_path} is missing required fields: #{missing}")
      end
      self.check_constructor
      self.store_config
    end

    # given the name of a target, return the path
    # to the definition YAML file. All +:target_dir+s defined in Settings are
    # searched and the first matching YAML file is loaded. 
    def locate_definition name
      Settings.instance.target_dir.each do |dir|
        Dir.chdir dir do
          Dir[name + '.yml'].each do |file|
            return ::File.expand_path file
          end
        end
      end

      nil
    end

    # verify that +:config+ contains values for all essential target settings
    # returning false if no keys are missing, or an array of the missing keys
    # if any cannot be found
    def check_config config
      required = %w(input_files output_files parameter_ranges constructor_path)
      missing = false
      required.each do |key|
        unless config.has_key? key.to_sym
          missing ||= []
          missing << key
        end
      end
      missing
    end


    def store_config config
      config.each_pair do |key, value|
        if self.instance_variable_defined? '@' + key.to_s
          self.instance_variable_set('@' + key.to_s, value)
        end
      end
    end

    def check_constructor
      self.valid_ruby? @constructor_path
    end

    # true if file is valid ruby
    def valid_ruby? file
      result = `ruby -c #{file}`
      !result.size.zero?
    end

  end # end of class Domain

end # end of module Biopsy