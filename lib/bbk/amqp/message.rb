# frozen_string_literal: true

module BBK
  module AMQP
    # Store information about consumed AMQP message
    class Message

      attr_reader :consumer, :headers, :body, :payload, :delivery_info, :properties

      def initialize(consumer, delivery_info, properties, body)
        @consumer = consumer
        @properties = properties.to_h.with_indifferent_access
        @body = body
        amqp_consumer = delivery_info[:consumer]
        @delivery_info = delivery_info.to_h.merge(
          message_consumer: consumer,
          protocols:        consumer.protocols,
          queue:            amqp_consumer&.queue_name
        )
        @headers = @properties.except(:headers).merge(properties[:headers]).with_indifferent_access
        @payload = begin
          Oj.load(body).with_indifferent_access
        rescue StandardError
          {}.with_indifferent_access
        end
      end

      def message_id
        headers[:message_id]
      end

      def reply_to
        headers[:reply_to]
      end

      def ack(*args, answer: nil, **kwargs)
        consumer.ack(self, *args, answer: answer, **kwargs)
      end

      def nack(*args, error: nil, **kwargs)
        consumer.nack(self, *args, error: error, **kwargs)
      end

    end
  end
end

