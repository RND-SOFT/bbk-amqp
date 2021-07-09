# frozen_string_literal: true

module Aggredator
  module AMQP
    # Store information about consumed AMQP message
    class Message

      attr_reader :consumer, :headers, :body, :payload, :delivery_info, :properties, :context

      def initialize(consumer, delivery_info, properties, body, context: {})
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
        @context = context
      end

      # Все методы идущие далее не являются частью интерфейса
      # общего для всех сообщений, и добавлены для обеспечения совместимости
      # с старым кодом

      def user_id
        headers[:user_id]
      end

      def message_id
        properties[:message_id] || headers[:message_id]
      end

      def id
        message_id
      end

      def reply_to
        properties[:reply_to] || headers[:reply_to] || user_id
      end

    end
  end
end

