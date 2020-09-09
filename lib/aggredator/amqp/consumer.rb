# frozen_string_literal: true

module Aggredator
  module AMQP
    class Consumer
      attr_reader :connection, :queue_name, :queue, :options

      DEFAULT_OPTIONS = {
        consumer_pool_size: 3,
        consumer_pool_abort_on_exception: true,
        prefetch_size: 10,
        requeue_on_reject: false,
        consumer_tag: nil
      }.freeze
      PROTOCOLS = %i[mq amqp amqps].freeze

      def initialize(connection, queue_name, options = {})
        @connection = connection
        @queue_name = queue_name
        @options = options.deep_dup.reverse_merge(DEFAULT_OPTIONS)
      end

      # Return protocol list which consumer support
      def protocols
        PROTOCOLS
      end

      def prepare; end

      # Running non blocking consumer
      # @param msg_stream [Enumerable] - object with << method
      def run(msg_stream)
        prepare
        @channel = @connection.create_channel(nil, options[:consumer_pool_size], options[:consumer_pool_abort_on_exception])
        @queue = @channel.queue(queue_name, passive: true)
        subscribe_opts = {
          block: false,
          manual_ack: true,
          consumer_tag: options[:consumer_tag]
        }.compact
        queue.subscribe(subscribe_opts) do |delivery_info, metadata, payload|
          message = Message.new(self, delivery_info, metadata, payload)
          msg_stream << message
        end
        msg_stream
      end

      # Ack incoming message and not send answer.
      # @note answer should processing amqp publisher
      # @param incoming [Aggredator::AMQP::Message] consumed message from amqp channel
      # @param answer [Aggredator::Dispatcher::Result] answer message
      def ack(incoming, answer: nil)
        # [] - для работы тестов. В реальности вернется объект VersionedDeliveryTag у
        #  которого to_i (вызывается внутри channel.ack) вернет фактическоe число
        @channel.ack incoming.delivery_info[:delivery_tag]
      end

      # Nack incoming message
      # @param incoming [Aggredator::AMQP::Message] nack procesing message
      def nack(incoming)
        @channel.reject incoming.delivery_info[:delivery_tag], requeue: options[:requeue_on_reject]
      end

      # Close consumer - try close amqp channel
      def close
        @channel.close
      end
    end
  end
end
