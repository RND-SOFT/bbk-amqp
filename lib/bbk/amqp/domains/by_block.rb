module BBK
  module AMQP
    module Domains
      class ByBlock

        attr_reader :name

        def initialize(name, &block)
          raise ArgumentError.new('no block') unless block_given?

          @name = name
          @block = block
        end

        def call(route)
          @block.call(route)
        end


      end
    end
  end
end

