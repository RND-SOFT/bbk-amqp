module BBK
  module AMQP
    module RejectionPolicies
      class Republish

        REPUBLISH_COUNTER_KEY = 'x-republish-count'.freeze

        attr_reader :logger

        def initialize(publisher, logger: BBK::Utils::Logger.default)
          @publisher = publisher
          @logger = ActiveSupport::TaggedLogging.new(logger).tagged(self.class.name)
        end

        def call(message, error, *_args, **_kwargs)
          if message.delivery_info[:redelivered] || message.headers.key?(REPUBLISH_COUNTER_KEY)
            republish_message(message, error)
          else
            requeue_message(message, error)
          end
        end

        def requeue_message(message, error)
          logger.warn "Requeue message #{message.headers[:type]}[#{message.headers[:message_id]}] delivery tag: #{message.delivery_info[:delivery_tag].to_i}. Error: #{error.inspect}"
          message.delivery_info[:channel].reject message.delivery_info[:delivery_tag], true
        end

        def republish_message(message, error)
          logger.warn "Republish message #{message.headers[:type]}[#{message.headers[:message_id]}]. Error: #{error.inspect}"
          msg = message.clone
          msg.headers[REPUBLISH_COUNTER_KEY] = msg.headers.fetch(REPUBLISH_COUNTER_KEY, 0).to_i + 1
          @publisher.publish_message(msg.delivery_info[:queue], msg, exchange: '').value!
          message.ack
        end


      end
    end
  end
end

