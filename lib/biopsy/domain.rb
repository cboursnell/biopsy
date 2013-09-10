  # input or output files defined in the spec
module Biopsy

  class DomainLoadError < Exception
  end

  class Domain

    attr_reader :name
    attr_reader :input_filetypes
    attr_reader :output_filetypes
    attr_reader :objectives
    attr_reader :keep_intermediates
    attr_reader :gzip_intermediates

    require 'yaml'
    require 'pp'

    # Return a new Domain object containing the specification of the
    # currently active domain.
    def initialize domain=nil
      @name = domain.nil? ? self.get_current_domain : domain

      @keep_intermediates = false
      @gzip_intermediates = false
      self.load_by_name @name
    end

    # Return the name of the currently active domain.
    def get_current_domain
      Settings.instance.domain
    rescue
      raise "You must specify the domain to use in the biopsy settings file or at the command line."
    end

    # Return the path to the YAML definition file for domain with +:name+.
    # All +:domain_dirs+ in Settings are searched and the first matching
    # file is returned.
    def locate_definition name
      Settings.instance.locate_config :domain_dir, name
    end

    # Check and apply the settings in +:config+ (Hash).
    def apply_config config
      [:input_filetypes, :output_filetypes, :objectives].each do |key|
        raise DomainLoadError.new("Domain definition is missing the required key #{key}") unless config.has_key? key 
        self.instance_variable_set('@' + key.to_s, config[key])
      end
    end

    # Load and apply the domain definition with +:name+
    def load_by_name name
      path = self.locate_definition name
      raise DomainLoadError.new("Domain definition file does not exist for #{name}") if path.nil?
      config = YAML::load_file(path)
      raise DomainLoadError.new("Domain definition file #{path} is not valid YAML") if config.nil?
      self.apply_config config.deep_symbolize
    end

    # Validate a Target, returning true if the target meets
    # the specification of this Domain, and false otherwise.
    # +:target+, the Target object to validate.
    def target_valid? target
      l = []
      @input_filetypes.each do |input|
        l << [target[:input_files], input, 'input']
      end
      @output_filetypes.each do |output|
        l << [target[:output_files], output, 'output']
      end
      errors = []
      l.each do |triplet|
        testcase, definition, type = triplet
        errors += self.validate_target_filetypes(testcase, definition, type)
      end
      errors
    end

    # Returns an empty array if +:testcase+ conforms to definition,
    # otherwise returns an array of strings describing the
    # errors found.
    def validate_target_filetypes testcase, definition, type
      errors = []
      # check extensions
      if definition.has_key? :allowed_extensions
        testcase.each_pair do |key, f|
          ext = File.extname(f)
          found = false
          definition[:allowed_extensions].each do |x|
            if x.downcase == ext.downcase || f.downcase == ext.downcase
              found = true 
            end
          end
          unless found
            errors << %Q{#{type} file #{f} doesn't match any of the filetypes
                         allowed for this domain (#{definition[:allowed_extensions]})}
          end
        end
      end
      # check number of files
      in_count = testcase.size
      if definition.has_key? :n
        unless in_count == definition[:n]
          errors << %Q{the number of #{type} files (#{in_count}) doesn't 
                      match the domain specification (#{definition[:n]})}
        end
      end
      if definition.has_key? :min
        unless in_count >= definition[:min]
          errors << %Q{the number of #{type} files (#{in_count}) is lower 
                      than the minimum for this domain (#{definition[:n]})}
        end
      end
      if definition.has_key? :max
        unless in_count >= definition[:max]
          errors << %Q{the number of #{type} files (#{in_count}) is greater 
                      than the maximum for this domain (#{definition[:n]})}
        end
      end
      errors
    end

    # Write out a template Domain definition to +:filename+
    def write_template filename
      data = {
        :input_filetypes => [
          {
            :min => 1,
            :max => 2,
            :allowed_extensions => [
              'txt',
              'csv',
              'tsv'
            ]
          },
          {
            :n => 2,
            :allowed_extensions => [
              'png'
            ]
          }
        ],
        :output_filetypes => [
          {
            :n => 1,
            :allowed_extensions => [
              'pdf',
              'xls'
            ]
          }
        ],
        :objectives => [
          'objective1', 'objective2'
        ]
      }
      ::File.open(filename, 'w') do |f|
        f.puts data.to_yaml
      end
    end

  end # end of class Domain

end # end of module Biopsy