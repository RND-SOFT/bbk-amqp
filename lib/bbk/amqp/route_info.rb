module BBK
  module AMQP
    class RouteInfo

      attr_reader :exchange, :routing_key

      def initialize(exchange, routing_key)
        @exchange = exchange
        @routing_key = routing_key
      end

    end
  end
end

