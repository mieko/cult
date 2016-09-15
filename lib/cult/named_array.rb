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
        name
      end
      ::Object.include(self)
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
      re = /\[([+-]?\d+)\]$/
      if key.is_a?(String) && (m = key.match(re))
        subs, index = m[0], m[1]
        [ key[0... key.size - subs.size], index.to_i ]
      else
        [ key, nil ]
      end
    end

    # Returns all keys that match if method == :select, the first if
    # method == :find
    def all(key, method = :select)
      return super if key.is_a?(Integer)
      return nil if key.nil?

      key, index = extract_index(key)
      predicate = expand_predicate(key)

      effective_method = index.nil? ? method : :select

      result = send(effective_method) do |v|
        predicate === v.named_array_identifier
      end

      case method
        when :select
          if index
            result = result[index]
            result = result.nil? ? [] : [result]
          end
          return result
        when :find
          return index ? result[index] : result
      end
    end


    # first matching item
    def [](key, index = nil)
      if key.is_a?(Integer)
        unless index.nil?
          fail ArgumentError, "cant specify index with an... index?"
        end

        return super(key)
      end

      index.nil? ? all(key, :find) : all(key, :select)[index]
    end


    # first matching item, or raises KeyError
    def fetch(key)
      all(key, :find) or raise KeyError
    end


    def key?(key)
      !! all(key, :find)
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
          Array(candidate.send(method)).any? { |r| predicate === r }
        end
      end
    end

    alias_method :where, :with
  end
end
