require 'set'
require 'concurrent'

module Aggredator
  module AMQP
    class Publisher

      HEADER_PROP_FIELDS = %i[user_id message_id reply_to correlation_id]
      PROTOCOLS = %i[mq amqp amqps]

      attr_reader :connection, :domains, :logger, :channel, :ack_map, :sended_messages, :channel

      def initialize(connection, domains, logger: Logger.new(IO::NULL))
        @connection = connection
        @channel = connection.channel
        @domains = domains
        @logger = logger
        @ack_map = Concurrent::Map.new
        @sended_messages = Concurrent::Map.new
        @configured_exchanges = Set.new
        initialize_callbacks
      end

      def protocols
        PROTOCOLS
      end

      def publish(result)
        route = result.route      
        raise RuntimeError.new("Unknown domain #{route.domain}") unless domains.has?(route.domain)
        exchange = domains[route.domain]
        message = result.message
        publish_message(route.routing_key, message, exchange: exchange, options: result.properties)
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
        ack_id = args[:ack_id]
        if self.ack_map.delete(ack_id) && (f = sended_messages.delete(ack_id)).present?
          neg = args[:neg]
          if neg
            f.reject(args)
          else
            f.fulfill(args)
          end
        end
      rescue StandardError => e
        logger.error "[CRITICAL]: #{e.inspect}.\n#{e.backtrace.first(10).join("\n")}"
      end

      private

      def initialize_callbacks
        @domains.each {|_, exchange_name| configure_exchange(exchange_name)}
        @channel.confirm_select method(:on_confirm).curry(4).call(channel)
      end

      def configure_exchange exchange_name
        return if @configured_exchanges.include?(exchange_name)
        exchange = channel.exchange(exchange_name, passive: true)
        exchange.on_return &method(:on_return).curry(4).call(exchange)
        @configured_exchanges << exchange_name
      end

      def client_name
        return connection.user unless connection.ssl?
        Utils.commonname(connection.transport.tls_certificate_path)
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
        configure_exchange(exchange)
        channel.synchronize do
          ack_id = channel.next_publish_seq_no
          options[:message_id] ||= SecureRandom.uuid
          # в случае укаказанного message_id в качестве числа, on_return вернет message_id в качестве строки
          ack_map[ack_id] = options[:message_id].to_s
          future = sended_messages[ack_id] = Concurrent::Promises.resolvable_future
          channel.basic_publish(payload.to_json, exchange, routing_key, options)
          future
        end
      end

    end
  end
end