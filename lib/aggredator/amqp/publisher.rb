require 'concurrent'

module Aggredator
  module AMQP
    class Publisher

      HEADER_PROP_FIELDS = %i[user_id message_id reply_to correlation_id]

      attr_reader :connection, :domains, :logger, :channel, :ack_map, :sended_messages

      def initialize(connection, domains, logger: Logger.new(IO::NULL))
        @connection = connection
        @domains = domains
        @logger = logger
        @ack_map = Concurrent::Map.new
        @sended_messages = Concurrent::Map.new
        @prepared = false
      end

      def publish(result)
        @channel = connection.channel
        prepare(channel) unless @prepared
        route = result.route
        exchange = domains[route.domain]
        raise RuntimeError.new("Unknown domain #{route.domain}") if exchange.blank?
        message = result.message
        publish_message(route.routing_key, message, exchange: exchange, options: message.properties)
      end

      def publish_message(routing_key, message, exchange: , options: {})
        properties = {
            persistent: true,
            mandatory: true,
            routing_key: routing_key,
            headers: message.headers,
            user_id: client_name, # если есть в headers, то на следующей строке будет перетерто
            **message.headers.select{|k| HEADER_PROP_FIELDS.include? k}.compact
        }.merge(options).symbolize_keys
        send_message(exchange, routing_key, message.payload, properties)
      end

      def raw_publish(routing_key, exchange:, properties: {}, headers: {}, payload: {})
        properties = properties.deep_dup
        properties[:headers] = properties.fetch(:headers, {}).merge headers
        properties = properties.merge(headers.select{|k| HEADER_PROP_FIELDS.include? k}.compact).symbolize_keys
        send_message(exchange, routing_key, payload, properties)
      end

      def prepare(channel)
        on_return = method(:on_return).curry(4)
        @domains.each do |_, exchange_name|
          exchange = channel.exchange(exchange_name, passive: true)
          exchange.on_return &on_return.call(exchange)
        end
        channel.confirm_select method(:on_confirm).curry(4).call(channel)
        @prepared = true
      end

      def message_returned(args)
        message_id = args[:properties][:message_id]
        ack_id, = self.ack_map.each_pair.find {|_, msg_id| msg_id == message_id }

        if self.ack_map.delete(ack_id)
          self.sended_messages.delete(ack_id)&.reject(args)
        end
      rescue StandardError => e
        logger.error "[CRITICAL]: #{e.inspect}.\n#{e.backtrace.first(10).join("\n")}"
      end

      def message_confirmed(args)
        if self.ack_map.delete(args[:ack_id])
          sended_messages.delete(args[:ack_id])&.fullfill(args)
        end
      rescue StandardError => e
        logger.error "[CRITICAL]: #{e.inspect}.\n#{e.backtrace.first(10).join("\n")}"
      end

      private

      def client_name
        return channel.user unless channel.ssl?
        Utils.commonname(channel.transport.tls_certificate_path)
      end

      def on_return(exchange, basic_return, properties, body)
        args = { exchange: exchange, basic_return: basic_return, properties: properties, body: body }
        message_returned(args)
      end

      def on_confirm(channel, ack_id, flag, neg)
        args = {channel: channel, ack_id: ack_id, flag: flag, neg: neg}
        message_confirmed(args)
      end

      def send_message(exchange, routing_key, payload, options)
        channel.synchronize do
          ack_id = channel.next_publish_seq_no
          ack_map[ack_id] = options[:message_id] ||= SecureRandom.uuid
          future = sended_messages[ack_id] = Concurrent::Promises.resolvable_future
          channel.basic_publish(payload.to_json, exchange, routing_key, options)
          future
        end
      end

    end
  end
end