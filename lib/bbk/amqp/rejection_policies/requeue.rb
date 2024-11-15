module BBK
  module AMQP
    module RejectionPolicies
      class Requeue

        attr_reader :logger

        def initialize(logger: BBK::Utils::Logger.default)
          @logger = logger
        end

        def call(message, error, *_args, **_kwargs)
          logger.debug "Requeue message #{message.headers[:type]}[#{message.headers[:message_id]}] delivery tag: #{message.delivery_info[:delivery_tag].to_i}. Error: #{error.inspect}"
          message.delivery_info[:channel].reject message.delivery_info[:delivery_tag], true
        end

      end
    end
  end
end

