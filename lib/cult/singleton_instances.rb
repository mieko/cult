module Cult
  module SingletonInstances

    module ClassMethods
      private
      def singletons
        @singletons ||= {}
      end


      def cache_get(cls, *args)
        singletons[[cls, *args]])
      end


      def cache_put(obj, *args)
        singletons[[obj.class, *args]] = obj
      end


      public
      def new(*args)
        return super unless Cult.singletons?

        return result if (result = cache_get(self, *args))

        super.tap do |result|
          cache_put(result, *args)
        end
      end

    end

    def self.included(cls)
      class << cls
        prepend(ClassMethods)
      end
    end
  end
end
