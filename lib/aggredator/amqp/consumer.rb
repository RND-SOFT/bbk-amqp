module Aggredator

  module AMQP
  
    class Consumer

      attr_reader :connection, :queue, :options

      DEFAULT_OPTIONS = {}

      def initialize(connection, queue, options = {})
        @connection = connection
        @queue = queue
        @options = options.deep_dup.reverse_merge(DEFAULT_OPTIONS)
      end

      def prepare; end

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

      def ack(incoming, answer: nil)
        @channel.ack incoming.delivery_info.delivery_tag
      end

      def nack(incoming)
        @channel.reject incoming.delivery_info.delivery_tag, requeue: false
      end

      def close
        @channel.close
      end

    end

  end

end