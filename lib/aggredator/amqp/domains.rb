# frozen_string_literal: true

module Aggredator
  module AMQP
    # Store for amqp domains. Domain is pair: domain name and exchange name.
    class Domains
      attr_reader :domains

      # Build default domains - common for v1 amqp aggredator services
      def self.default
        new(outer: '', direct: '', inner: 'main_exchange', gw: 'gw', Aggredator::Dispatcher::ANSWER_DOMAIN.to_sym => '')
      end

      def initialize(domains = {})
        @domains = domains.with_indifferent_access
      end

      # Get exchange name by domain
      # @param domain_name [String] domain name
      # @return [String] exchange name configured for passed domain name
      def [](domain_name)
        domains[domain_name]
      end

      # Each method implementation for object iteration
      def each(&block)
        domains.each(&block)
      end

      # Check if store has information about domain
      # @param domain_name [String] domain name
      # @return [Boolean] has information about domain
      def has?(domain_name)
        domains.key? domain_name
      end
    end
  end
end
