module Aggredator
  module AMQP
    # Specific for amqp domains
    class Domains

      attr_reader :domains

      def self.default
        self.new(outer: "",  direct: "", inner: "main_exchange",  gw: "gw", Aggredator::Dispatcher::ANSWER_DOMAIN.to_sym => "")
      end

      def initialize(domains)
        @domains = domains.with_indifferent_access
      end

      def [](key)
        domains[key]
      end

      def each &block
        domains.each &block
      end

      def has?(domain)
        domains.has_key? domain
      end

    end
  end
end
