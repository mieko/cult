require 'yaml'
require 'json'
require 'forwardable'

require 'cult/template'

module Cult
  class Definition
    attr_reader :object
    attr_reader :bag

    extend Forwardable
    def_delegators :object, :definition_parameters, :definition_path,
                            :definition_parents

    def initialize(object)
      @object = object
    end

    def inspect
      "\#<#{self.class.name} " +
        "object: #{object.inspect}, " +
        "params: #{definition_parameters}, " +
        "parents: #{definition_parents}, " +
        "direct_values: #{bag}>"
    end
    alias_method :to_s, :inspect


    def candidates
      [ "#{definition_path}.yaml", "#{definition_path}.yml",
        "#{definition_path}.json" ]
    end


    # Finds the first existing file in the candidate list
    def filename
      @filename ||= begin
        results = candidates.select do |candidate|
          File.exist?(candidate)
        end
        if results.size > 1
          raise RuntimeError, "conflicting definition files: #{result.inspect}"
        end
        results[0]
      end
    end


    def decoder_for(filename)
      @decoder_for ||= begin
        case filename
          when nil
            nil
          when /\.json\z/
            JSON.method(:parse)
          when /\.ya?ml\z/
            YAML.method(:safe_load)
          else
            fail RuntimeError, "No decoder for file type: #{filename}"
        end
      end
    end


    def bag
      @bag ||= begin
        if filename.nil?
          {}
        else
          erb = Template.new(definition_parameters)
          contents = erb.process(File.read(filename))
          decoder_for(filename).call(contents)
        end
      end
    end
    alias_method :to_h, :bag

    def direct(k)
      fail "Use string keys" unless k.is_a?(String)
      bag[k]
    end

    def [](k)
      fail "Use string keys" unless k.is_a?(String)
      if bag.key?(k)
        bag[k]
      else
        parent_responses = definition_parents.map do |p|
          [p, p.definition[k]]
        end.reject do |k, v|
          v.nil?
        end
        consensus = parent_responses.group_by(&:last)
        if consensus.empty?
          return nil
        elsif consensus.size != 1
          msg = "#{object.inspect}: I didn't have key '#{k}', and " +
                "my parents had conflicting answers: " +
                "[answer, parents]: #{consensus}"
          fail KeyError, msg
        end
        consensus.keys[0]
      end
    end

    def []=(k, v)
      fail "Use string keys" unless k.is_a?(String)
      bag[k] = v
    end

  end
end
