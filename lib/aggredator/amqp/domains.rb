module Aggredator
  module AMQP
    # Specific for amqp domains
    class Domains

      attr_reader :domains

      def self.default
        self.new(outer: "",  direct: "", Aggredator::Dispatcher::ANSWER_DOMAIN => "", inner: "",  gw: "gw")
      end

      def initialize(**kwargs)
        @domains = kwargs.with_indifferent_access
      end

      def [](key)
        domains[key]
      end

      def each &block
        domains.each block
      end

    end
  end
end
