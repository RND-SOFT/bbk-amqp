# frozen_string_literal: true

module Aggredator
  module AMQP
    # Store amqp domains, and allow change/configure in after creation.
    # Use it in custom/specific cases such mix rails and backbone gem.
    class MutableDomains < Domains


      # Add/update exchange for domain name
      # @param domain_name [String] domain name
      # @param exchange [String] exchange name
      def []=(domain_name, exchange)
        @domains[domain_name] = exchange
      end

    end
  end
end

