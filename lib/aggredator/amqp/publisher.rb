# frozen_string_literal: true

require 'set'
require 'concurrent'

module Aggredator
  module AMQP
    class Publisher

      HEADER_PROP_FIELDS = %i[user_id message_id reply_to correlation_id].freeze
      PROTOCOLS = %w[mq amqp amqps].freeze

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

      # Returned supported protocols list
      # @return [Array<Symbol>]
      def protocols
        PROTOCOLS
      end

      # Publish dispatcher result
      # @param result [Aggredator::Dispatcher::Result] sended result
      def publish(result)
        logger.debug "Try publish dispatcher result #{result.inspect}"
        route = result.route
        result_domain = route.domain
        raise "Unsupported protocol #{route.scheme}" unless PROTOCOLS.include?(route.scheme)
        raise "Unknown domain #{result_domain}" unless domains.has?(result_domain)

        exchange = domains[result_domain]
        message = result.message
        publish_message(route.routing_key, message, exchange: exchange, options: result.properties)
      end

      # Publish message
      # @param routing_key [String] message routing key
      # @param message [Object] (object with headers and payload method)
      # @param exchange [Object] exchange for sending message
      # @param options [Hash] message properties
      def publish_message(routing_key, message, exchange:, options: {})
        logger.debug "Try publish message #{message.headers.inspect}"
        properties = {
          persistent:  true,
          mandatory:   true,
          routing_key: routing_key,
          headers:     message.headers,
          user_id:     client_name, # если есть в headers, то на следующей строке будет перетерто
          **message.headers.select {|k| HEADER_PROP_FIELDS.include? k }.compact
        }.merge(options).symbolize_keys
        send_message(exchange, routing_key, message.payload, properties)
      end

      # Publish raw payload
      # @param routing_key [String] routing key for sending data
      # @param exchange [String] exchange name
      # @param properties [Hash] amqp message properties
      # @param headers [Messag]
      def raw_publish(routing_key, exchange:, properties: {}, headers: {}, payload: {})
        logger.debug "Publish raw message #{headers.inspect}"
        properties = properties.deep_dup
        properties[:headers] = properties.fetch(:headers, {}).merge headers
        properties = properties.merge(headers.select {|k| HEADER_PROP_FIELDS.include? k }.compact).symbolize_keys
        send_message(exchange, routing_key, payload, properties)
      end

      private

        # Initialize amqp callbacks
        def initialize_callbacks
          @domains.each {|_, exchange_name| configure_exchange(exchange_name) }
          @channel.confirm_select method(:on_confirm).curry(4).call(channel)
        end

        # Configure on return callback for exchange
        def configure_exchange(exchange_name)
          return if @configured_exchanges.include?(exchange_name)

          logger.debug "Configure on_return callback for exchange #{exchange_name}"
          exchange = channel.exchange(exchange_name, passive: true)
          exchange.on_return(&method(:on_return).curry(4).call(exchange))
          @configured_exchanges << exchange_name
        end

        # Get connection user. If tls connectoin try extract CN from connection tls_cert
        # @return [String] user name
        def client_name
          return connection.user unless connection.ssl?

          Utils.commonname(connection.transport.tls_certificate_path)
        end

        def on_return(exchange, basic_return, properties, body)
          args = { exchange: exchange, basic_return: basic_return, properties: properties, body: body }
          message_id = properties[:message_id]
          logger.info "Message with message_id #{message_id} returned #{basic_return.inspect}"
          ack_id, = ack_map.each_pair.find {|_, msg_id| msg_id == message_id }

          sended_messages.delete(ack_id)&.reject(args) if ack_map.delete(ack_id)
        rescue StandardError => e
          # TODO: возможно стоит попробовать почистить ack_map и sended_messages
          logger.error "[CRITICAL]: #{e.inspect}.\n#{e.backtrace.first(10).join("\n")}"
        end

        def on_confirm(channel, ack_id, flag, neg)
          logger.debug "Call confirmed callback for message with ack_id #{ack_id} with neg=#{neg}"
          args = { channel: channel, ack_id: ack_id, flag: flag, neg: neg }
          if ack_map.delete(ack_id) && (f = sended_messages.delete(ack_id)).present?
            if neg
              f.reject(args)
            else
              f.fulfill(args)
            end
          end
        rescue StandardError => e
          # TODO: возможно стоит попробовать почистить ack_map и sended_messages
          logger.error "[CRITICAL]: #{e.inspect}.\n#{e.backtrace.first(10).join("\n")}"
        end

        # Send amqp message and save meta information for processing
        # @param exchange [String] exchange name
        # @param routing_key [String] message routing key
        # @param payload [Object] message payload. Converted to json calling to_json method
        # @param options [Hash] amqp message properties
        # @return [Concurrent::Promises::ResolvableFuture] future for checking success publishing
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

