# frozen_string_literal: true

module BBK
  module AMQP
    # Store for amqp domains. Domain is pair: domain name and exchange name.
    class DomainsSet

      def initialize(*domains)
        @domains = domains.map{|d| [d.name.to_s, d] }.to_h
      end

      # Get exchange name by domain
      # @param domain_name [String] domain name
      # @return [String] exchange name configured for passed domain name
      def [](domain_name)
        @domains[domain_name]
      end

      def add(domain)
        @domains[domain.name.to_s] = domain
      end

      alias << add

      # Each method implementation for object iteration
      def each(&block)
        @domains.values.each(&block)
      end

      # Check if store has information about domain
      # @param domain_name [String] domain name
      # @return [Boolean] has information about domain
      def has?(domain_name)
        @domains.key? domain_name
      end

    end
  end
end

