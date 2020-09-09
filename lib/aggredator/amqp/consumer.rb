module Aggredator

  module AMQP
  
    class Consumer

      attr_reader :connection, :queue, :options

      DEFAULT_OPTIONS = {}
      PROTOCOLS = %i[mq amqp amqps]

      def initialize(connection, queue, options = {})
        @connection = connection
        @queue = queue
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
        @channel = @connection.channel
        if queue.is_a?(String)
          @queue = @channel.queue(queue, passive: true)
        end
        queue.subscribe(block: false, manual_ack: true) do |delivery_info, metadata, payload|
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
        @channel.ack incoming.delivery_info.delivery_tag
      end

      # Nack incoming message
      # @param incoming [Aggredator::AMQP::Message] nack procesing message
      def nack(incoming)
        @channel.reject incoming.delivery_info.delivery_tag, requeue: false
      end

      # Close consumer - try close amqp channel
      def close
        @channel.close
      end

    end

  end

end