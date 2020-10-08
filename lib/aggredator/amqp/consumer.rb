# frozen_string_literal: true

module Aggredator
  module AMQP
    class Consumer

      attr_reader :connection, :queue_name, :queue, :options, :logger

      DEFAULT_OPTIONS = {
        consumer_pool_size:               3,
        consumer_pool_abort_on_exception: true,
        prefetch_size:                    10,
        requeue_on_reject:                false,
        consumer_tag:                     nil
      }.freeze
      PROTOCOLS = %w[mq amqp amqps].freeze

      def initialize(connection, queue_name = nil, options = {})
        @connection = connection
        @channel = options.delete(:channel)
        @queue = options.delete(:queue)

        raise 'queue_name or queue must be provided!' if @queue_name.nil? && queue_name.nil?

        @queue_name = @queue&.name || queue_name

        @options = options.deep_dup.reverse_merge(DEFAULT_OPTIONS)
        @logger = @options.fetch(:logger, ::Logger.new(STDOUT))
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

        @channel ||= @connection.create_channel(nil, options[:consumer_pool_size], options[:consumer_pool_abort_on_exception]).tap do |ch|
          ch.prefetch(options[:prefetch_size])
        end

        @queue ||= @channel.queue(queue_name, passive: true)

        subscribe_opts = {
          block:        false,
          manual_ack:   true,
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
        logger.debug 'ack message'
        @channel.ack incoming.delivery_info[:delivery_tag]
      end

      # Nack incoming message
      # @param incoming [Aggredator::AMQP::Message] nack procesing message
      def nack(incoming, error: nil)
        logger.info 'reject message'
        @channel.reject incoming.delivery_info[:delivery_tag], options[:requeue_on_reject]
      end

      # Close consumer - try close amqp channel
      def close
        @channel.close
      end

    end
  end
end

