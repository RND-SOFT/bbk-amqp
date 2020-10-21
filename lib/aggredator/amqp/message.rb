# frozen_string_literal: true

module Aggredator
  module AMQP
    # Store information about consumed AMQP message
    class Message

      attr_reader :consumer, :headers, :body, :payload, :delivery_info, :properties

      def initialize(consumer, delivery_info, properties, body)
        @consumer = consumer
        @properties = properties.to_h.with_indifferent_access
        @body = body
        @delivery_info = delivery_info.to_h.merge(message_consumer: consumer, protocols: consumer.protocols)
        @headers = @properties.except(:headers).merge(properties[:headers]).with_indifferent_access
        @payload = begin
                     JSON.parse(body).with_indifferent_access
                   rescue StandardError
                     {}.with_indifferent_access
                   end
      end

    end
  end
end

