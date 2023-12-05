module BBK
  module AMQP
    class RouteInfo

      attr_reader :exchange, :routing_key, :headers

      def initialize(exchange, routing_key, **headers_params)
        @exchange = exchange
        @routing_key = routing_key
        @headers = headers_params
      end

    end
  end
end

