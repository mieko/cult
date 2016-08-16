# A lot of times, we want a sequential array, of objects, but it'd still be
# really convenient to refer to things by their name.  This is particularly
# painful in the console, where, e.g., nodes can only be referred to by index,
# and you end up calling `find` a lot.
#
# NamedArray is an array, but overloads [] to also work with a string or symbol.
# e.g., nodes[:something].  It works by finding the first item who responds
# from `named_array_identifier` with the matching key.
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
                       rotate select shuffle slice sort uniq)
    PROXY_METHODS.each do |method_name|
      define_method(method_name) do |*args, &b|
        r = super(*args, &b)
        r.respond_to?(:to_named_array) ? r.to_named_array : r
      end
    end

    # Returns all keys that match if method == :select, the first if
    # method == :find
    def all(key, method = :select)
      key = case key
        when Integer
          # Fallback to default behavior
          return super
        when String, Regexp, Proc, Range
          key
        when Symbol
          key.to_s
        else
          fail ArgumentError
      end
      send(method) { |v| key === v.named_array_identifier }
    end

    # first matching item
    def [](key)
      return super if key.is_a?(Integer)
      all(key, :find)
    end

    # first matching item, or raises KeyError
    def fetch(key)
      all(key, :find) or raise KeyError
    end

    def key?(key)
      !! all(key, :find)
    end

    def keys
      map(&:named_array_identifier)
    end

    def values
      self
    end
  end
end
