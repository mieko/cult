require 'yaml'
require 'json'
require 'cult/template'

module Cult
  class Definition
    attr_reader :path
    attr_reader :file
    attr_reader :decoder

    def initialize(path)
      @path = path
      @file = locate_file
      @decoder = decoder_for(@file)
    end

    def locate_file
      candidates.find do |candidate|
        File.exist?(candidate)
      end
    end

    def candidates
      [ path, "#{path}.yaml", "#{path}.yml", "#{path}.json" ]
    end

    def decoder_for(file)
      case file
        when nil
          nil
        when /\.json\z/
          JSON.method(:parse)
        when /\.ya?ml\z/
          YAML.method(:safe_load)
        else
          fail RuntimeError, "No decoder for file type: #{file}"
      end
    end

    def process(**kw)
      if file
        contents = File.read(file)
        erb = Template.new(kw)
        contents = erb.process(contents)
        decoder_for(file).call(contents)
      else
        {}
      end
    end

    def self.load(path, **kw)
      new(path).process(kw)
    end
  end

end
