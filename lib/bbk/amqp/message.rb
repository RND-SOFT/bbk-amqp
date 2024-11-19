# frozen_string_literal: true

require 'bbk/app/dispatcher/message'

module BBK
  module AMQP
    # Store information about consumed AMQP message
    class Message < BBK::App::Dispatcher::Message

      attr_reader :properties

      def initialize(consumer, delivery_info, properties, body)
        @properties = properties.to_h.with_indifferent_access
        headers = @properties.except(:headers).merge(@properties[:headers].presence || {}).with_indifferent_access

        amqp_consumer = delivery_info[:consumer]
        delivery_info = delivery_info.to_h.merge(
          message_consumer: consumer,
          protocols:        consumer.protocols,
          queue:            amqp_consumer&.queue_name
        )

        super(consumer, delivery_info, headers, body)
      end

      def message_id
        headers[:message_id]
      end

      def reply_to
        headers[:reply_to] || user_id
      end

      def user_id
        headers[:user_id]
      end

      def clone
        self.class.new(consumer, delivery_info, properties, body)
      end

      def protocol
        consumer&.protocols&.first
      end

      def inspect # :nodoc:
        "#<#{self.class.name} @consumer=#{consumer.class.name}, @delivery_info=#{delivery_info.except(:message_consumer).inspect}, @headers=#{headers.inspect}, @properties=#{@properties.inspect}>"
      end

    end
  end
end

