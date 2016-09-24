# A lot of times, we want a sequential array of objects, but it'd still be
# really convenient to refer to things by their name.  This is particularly
# painful in the console, where, e.g., nodes can only be referred to by index,
# and you end up calling `find` a lot.
#
# NamedArray is an array, but overloads [] to also work with a String, Symbol,
# Regexp, or a few other things. e.g., nodes[:something].  It works by finding
# the first item who responds from `named_array_identifier` with the matching
# key.
#
# By default named_array_identifier returns name, but this can be overridden.

module Cult
  class NamedArray < Array
    # Any Array can convert itself to a NamedArray
    module ArrayExtensions
      def to_named_array
        NamedArray.new(self)
      end
      ::Array.include(self)
    end


    # This maps #named_array_identifier to #name by default
    module ObjectExtensions
      def named_array_identifier
        respond_to?(:name) ? name : nil
      end
      ::Object.include(self)
    end

    # Allows named_array.all[/something/]
    class IndexWrapper
      def initialize(ary, method_name)
        @ary, @method_name = ary, method_name
      end

      def inspect
        "\#<#{self.class.name}>"
      end

      def [](*args)
        @ary.send(@method_name, *args)
      end

      def to_a
        @ary
      end
      alias_method :to_ary, :to_a

      def to_named_array
        @ary.to_named_array
      end
    end
    private_constant :IndexWrapper

    def self.indexable_wrapper(method_name)
      old_method_name = "#{method_name}_without_wrapper"
      alias_method old_method_name, method_name
      define_method(method_name) do |*a|
        if a.empty?
          return IndexWrapper.new(self, method_name)
        else
          return send(old_method_name, *a)
        end
      end
    end


    def to_named_array
      self
    end


    # Wrap any non-mutating methods that can return an Array,
    # and wrap the result with a NamedArray.  This is why NamedArray.select
    # results in a NamedArray instead of an Array
    PROXY_METHODS = %i(& * + - << | collect compact flatten reject reverse
                       rotate select shuffle slice sort uniq sort_by)
    PROXY_METHODS.each do |method_name|
      define_method(method_name) do |*args, &b|
        r = super(*args, &b)
        r.respond_to?(:to_named_array) ? r.to_named_array : r
      end
    end


    # It's unforunate that there's not a Regexp constructor that'll
    # accept this string format with options.
    def build_regexp_from_string(s)
      fail RegexpError, "Isn't a Regexp: #{s}" if s[0] != '/'
      options = extract_regexp_options(s)
      Regexp.new(s[1 ... s.rindex('/')], options)
    end
    private :build_regexp_from_string


    def extract_regexp_options(s)
      offset = s.rindex('/')
      fail RegexpError, "Unterminated Regexp: #{s}" if offset == 0

      trailing = s[offset + 1 ... s.size]
      re_string = "%r!!#{trailing}"
      begin
        (eval re_string).options
      rescue SyntaxError => e
        fail RegexpError, "invalid Regexp options: #{trailing}"
      end
    end
    private :extract_regexp_options


    # Most of the named-array predicates are meant to be useful for user input
    # or an interactive session.  We give special behavior to certain strings
    # the user might enter to convert them to a regexp, etc.
    def expand_predicate(predicate)
      case predicate
        when String
          predicate[0] == '/' ? build_regexp_from_string(predicate) : predicate
        when Regexp, Proc, Range
          predicate
        when Symbol, Integer
          ->(v) { predicate.to_s == v.to_s }
        when NilClass
          nil
        else
          predicate
      end
    end
    private :expand_predicate

    def extract_index(key)
      re = /\[\s*([^\]]*)\s*\]$/
      if key.is_a?(String) && (m = key.match(re))
        subs, expr = m[0], m[1]
        index = case expr
          when /^(\-?\d+)$/; $1.to_i #.. $1.to_i
          when /^(\-?\d+)\s*\.\.\s*(\-?\d+)$/; $1.to_i .. $2.to_i
          when /^(\-?\d+)\s*\.\.\.\s*(\-?\d+)$/; $1.to_i ... $2.to_i
          when /^((?:\-?\d+\s*,?\s*)+)$/; $1.split(',').map(&:to_i)
        end
        # We return [predicate string with index removed, expanded index]
        [ key[0 ... key.size - subs.size], index ]
      else
        [ key, nil ]
      end
    end

    def fetch_by_index(ary, index)
      case index
        when Array
          ary.values_at(*index).compact
        when Integer
          v = ary.at(index)
          v.nil? ? [] : [v]
        when Range
          ary[index]
        else
          fail ArgumentError, "weird index: #{index.inspect}"
      end
    end

    def normal_key?(k)
      [Integer, Range].any?{|cls| k.is_a?(cls) }
    end

    # Returns all keys that match if method == :select, the first if
    # method == :find
    def all(key, method = :select)
      return [self[key]] if normal_key?(key)
      return [] if key.nil?

      key, index = extract_index(key)
      predicate = expand_predicate(key)
      effective_method = index.nil? ? method : :select

      result = send(effective_method) do |v|
        predicate === v.named_array_identifier
      end

      result = fetch_by_index(result, index) if index
      Array(result).to_named_array
    end
    indexable_wrapper :all


    # first matching item
    def [](key)
      return super if normal_key?(key)
      all(key).first
    end

    def first(key = nil)
      return super() if key.nil?
      all(key, :find).first
    end

    # first matching item, or raises KeyError
    def fetch(key)
      first(key) or raise KeyError, "Not found: #{key.inspect}"
    end


    def key?(key)
      !! first(key)
    end
    alias_method :exist?, :key?


    def keys
      map(&:named_array_identifier)
    end


    def values
      self
    end

    # Takes a predicate in the form of:
    #   key: value
    # And returns all items that both respond_to?(key), and
    # predicate === the result of sending key.
    #
    # Instances can override what predicates mean by defining "names_for_*" to
    # override what is tested.
    #
    # For example, if you have an Object that contains a list of "Foos", but
    # you want to select them by name, you'd do something like:
    #
    # class Object
    #   attr_reader :foos   # Instances of Foo class
    #
    #   def names_for_foos  # Now we can select by name
    #     foos.map(&:name)
    #   end
    # end
    #
    def with(**kw)
      fail ArgumentError, "with requires exactly one predicate" if kw.size != 1

      key, predicate = kw.first
      predicate = expand_predicate(predicate)

      select do |candidate|
        methods = [key, "query_for_#{key}", "names_for_#{key}"].select do |m|
          candidate.respond_to?(m)
        end

        methods.any? do |method|
          Array(candidate.send(method)).any? do |r|
            begin
              predicate === r
            rescue
              # We're going to assume this is a result of a string
              # comparison to a custom #==
              false
            end
          end
        end
      end
    end

    alias_method :where, :with
  end
end
