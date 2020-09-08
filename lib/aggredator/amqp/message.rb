module Aggredator

  module AMQP
  
    class Message
    
      attr_reader :consumer, :headers, :body, :payload, :delivery_info

      def initialize(consumer, properties, body, delivery_info)
        @consumer = consumer
        @properties = properties
        @body = body
        @delivery_info = delivery_info.to_h.merge(consumer: consumer, protocols: consumer.protocols)
        @headers = properties.except(:headers).merge(properties[:headers])
      end

    end

  end

end