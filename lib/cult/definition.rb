require 'json'

module Cult
  class Definition
    attr_reader :object
    attr_reader :bag

    def initialize(object)
      @object = object
    end

    def definition_parameters
      object.definition_parameters
    end

    def definition_path
      object.definition_path
    end

    def definition_parents
      object.definition_parents
    end

    def inspect
      "\#<#{self.class.name} " +
        "object: #{object.inspect}, " +
        "params: #{definition_parameters}, " +
        "parents: #{definition_parents}, " +
        "bag: #{bag}>"
    end
    alias_method :to_s, :inspect

    def bag
      @bag ||= Array(definition_path).select do |filename|
        File.exist?(filename)
      end.inject({}) do |acc, filename|
        erb = ::Cult::Template.new(project: nil, **definition_parameters)
        contents = erb.process(File.read(filename), filename: filename)
        JSON.parse(contents).merge(acc)
      end
    end
    alias_method :to_h, :bag


    def direct(k)
      fail ArgumentError unless k.is_a?(String)
      bag[k]
    end


    def [](k)
      fail ArgumentError unless k.is_a?(String)
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
