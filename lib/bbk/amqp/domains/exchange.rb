module BBK
  module AMQP
    module Domains
      class Exchange


        attr_reader :name, :exchange

        def initialize(name, exchange)
          @name = name
          @exchange = exchange
        end

        def call(route)
          BBK::AMQP::RouteInfo.new(exchange, route.routing_key)
        end

      end
    end
  end
end

