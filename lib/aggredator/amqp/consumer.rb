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

        @options = DEFAULT_OPTIONS.merge(options)

        logger = @options.fetch(:logger, Aggredator::AMQP.logger)
        logger = logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
        @logger = Aggredator::AMQP::ProxyLogger.new(logger, tags: [self.class.to_s, queue_name])
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

        @logger.add_tags "Ch##{@channel.id}"

        @queue ||= @channel.queue(queue_name, passive: true)

        subscribe_opts = {
          block:        false,
          manual_ack:   true,
          consumer_tag: options[:consumer_tag]
        }.compact

        logger.info 'Starting...'
        @subscription = queue.subscribe(subscribe_opts) do |delivery_info, metadata, payload|
          message = Message.new(self, delivery_info, metadata, payload)
          # logger.debug "Consumed message #{message.headers[:type]}[#{message.headers[:message_id]}] on channel: #{delivery_info.channel&.id}[#{delivery_info.channel&.object_id}] delivery tag: #{message.delivery_info[:delivery_tag].to_i}"
          logger.debug "Consumed message #{message.headers[:type]}[#{message.headers[:message_id]}] delivery tag: #{message.delivery_info[:delivery_tag].to_i}"

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
        # logger.debug "Ack message #{incoming.headers[:type]}[#{incoming.headers[:message_id]}] on channel: #{incoming.delivery_info[:channel]&.id}[#{incoming.delivery_info[:channel]&.object_id}] delivery tag: #{incoming.delivery_info[:delivery_tag].to_i}"
        logger.debug "Ack message #{incoming.headers[:type]}[#{incoming.headers[:message_id]}]  delivery tag: #{incoming.delivery_info[:delivery_tag].to_i}"
        incoming.delivery_info[:channel].ack incoming.delivery_info[:delivery_tag]
      end

      # Nack incoming message
      # @param incoming [Aggredator::AMQP::Message] nack procesing message
      def nack(incoming, error: nil)
        logger.debug "Reject message #{incoming.headers[:type]}[#{incoming.headers[:message_id]}] delivery tag: #{incoming.delivery_info[:delivery_tag].to_i}. Error: #{error.inspect}"
        incoming.delivery_info[:channel].reject incoming.delivery_info[:delivery_tag], options[:requeue_on_reject]
      end

      # stop consuming messages
      def stop
        @subscription.tap do |s|
          return nil unless s

          logger.info 'Stopping...'
          @subscription = nil
          s.cancel
        end
      end

      # Close consumer - try close amqp channel
      def close
        @channel.tap do |c|
          return nil unless c

          logger.info 'Closing...'
          @channel = nil
          c.close
          logger.info 'Stopped'
        end
      end

    end
  end
end

