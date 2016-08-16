class Object
  def named_array_identifier
    name
  end
end

module Cult
  module ArrayExtensions
    def to_named_array
      NamedArray.new(self)
    end
  end
  ::Array.prepend(ArrayExtensions)

  class NamedArray < Array
    def to_named_array
      self
    end

    superclass.instance_methods(false).each do |method_name|
      method_name = method_name.to_s
      unless ['?', '!'].include?(method_name[-1])
        define_method(method_name) do |*args, &b|
          r = super(*args, &b)
          r.respond_to?(:to_named_array) ? r.to_named_array : r
        end
      end
    end

    def [](key)
      case key
        when Numeric
          super
        when String, Symbol
          key = key.to_s
          find { |v| v.named_array_identifier == key }
        else
          fail ArgumentError
      end
    end

    def fetch(v)
      self[v] or raise KeyError
    end

    def include?(v)
      !! self[v]
    end
  end
end
