module Aggredator

  module AMQP

    # Store information about consumed AMQP message
    class Message
    
      attr_reader :consumer, :headers, :body, :payload, :delivery_info, :properties

      def initialize(consumer, delivery_info, properties, body)
        @consumer = consumer
        @properties = properties.to_h
        @body = body
        @delivery_info = delivery_info.to_h.merge(message_consumer: consumer, protocols: consumer.protocols)
        @headers = @properties.except(:headers).merge(properties[:headers])
        @payload = JSON.parse(body) rescue {}
      end

    end

  end

end