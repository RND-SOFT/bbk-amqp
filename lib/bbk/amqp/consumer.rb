# frozen_string_literal: true
require 'bbk/amqp/rejection_policies/requeue'

module BBK
  module AMQP
    class Consumer

      attr_reader :connection, :queue_name, :queue, :rejection_policy, :options, :logger
      attr_accessor :publisher

      DEFAULT_OPTIONS = {
        consumer_pool_size:               3,
        consumer_pool_abort_on_exception: true,
        prefetch_size:                    10,
        consumer_tag:                     nil,
        rejection_policy:                 RejectionPolicies::Requeue.new
      }.freeze

      PROTOCOLS = %w[mq amqp amqps].freeze

      def initialize(connection, queue_name: nil, publisher: nil, **options)
        @connection = connection
        @channel = options.delete(:channel)
        @queue = options.delete(:queue)
        @publisher = publisher

        if @queue.nil? && queue_name.nil?
          raise ArgumentError.new('queue_name or queue must be provided!')
        end

        @queue_name = @queue&.name || queue_name

        @options = DEFAULT_OPTIONS.merge(options)
        @rejection_policy = @options.delete(:rejection_policy)

        logger = @options.fetch(:logger, BBK::AMQP.logger)
        logger = logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
        @logger = BBK::Utils::ProxyLogger.new(logger, tags: [self.class.to_s, queue_name])
      end

      # Return protocol list which consumer support
      def protocols
        PROTOCOLS
      end

      # Running non blocking consumer
      # @param msg_stream [Enumerable] - object with << method
      def run(msg_stream)
        @channel ||= @connection.create_channel(nil, options[:consumer_pool_size],
                                                options[:consumer_pool_abort_on_exception]).tap do |ch|
          ch.prefetch(options[:prefetch_size])
        end

        logger.add_tags "Ch##{@channel.id}"

        @queue ||= @channel.queue(queue_name, passive: true)

        subscribe_opts = {
          block:        false,
          manual_ack:   true,
          consumer_tag: options[:consumer_tag],
          exclusive: options.fetch(:exclusive, false)
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
      # @param incoming [BBK::AMQP::Message] consumed message from amqp channel
      # @param answer [BBK::App::Dispatcher::Result] answer message
      def ack(incoming, *args, answer: nil, **kwargs)
        # [] - для работы тестов. В реальности вернется объект VersionedDeliveryTag у
        #  которого to_i (вызывается внутри channel.ack) вернет фактическоe число
        # logger.debug "Ack message #{incoming.headers[:type]}[#{incoming.headers[:message_id]}] on channel: #{incoming.delivery_info[:channel]&.id}[#{incoming.delivery_info[:channel]&.object_id}] delivery tag: #{incoming.delivery_info[:delivery_tag].to_i}"
        send_answer(incoming, answer) unless answer.nil?
        logger.debug "Ack message #{incoming.headers[:type]}[#{incoming.headers[:message_id]}]  delivery tag: #{incoming.delivery_info[:delivery_tag].to_i}"
        incoming.delivery_info[:channel].ack incoming.delivery_info[:delivery_tag]
      end

      protected def send_answer(incoming, answer)
        if publisher.nil?
          logger.error "Can't answer message: empty publisher"
          raise "Publisher not configured in consumer #{self.inspect}"
        end
        logger.debug "Send answer message for incoming(message_id=#{incoming.message_id}) to #{answer.route}"
        publisher.publish(answer).value!
      end

      # Nack incoming message
      # @param incoming [BBK::AMQP::Message] nack procesing message
      def nack(incoming, *args, error: nil, **_kwargs)
        rejection_policy.call(incoming, error)
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

