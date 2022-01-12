# frozen_string_literal: true

require 'bunny'
require 'openssl'

module BBK
  module AMQP
    module Utils

      # Try get message from amqp queue
      # @param queue [Bunny::Queue]
      # @param timeout [Integer] in seconds for waiting message message in queue
      # @raise [Timeout::Error] if queue empty in timeout time duration
      # @return [Array] array with delivery_info, metadata and payload
      def self.pop(queue, timeout = 10)
        unblocker = Queue.new
        consumer = queue.subscribe(block: false) do |delivery_info, metadata, payload|
          message = [
            delivery_info,
            metadata.to_hash.with_indifferent_access,
            begin
              Oj.load(payload).with_indifferent_access
            rescue StandardError
              payload
            end
          ]
          unblocker << message
        end
        Thread.new do
          sleep timeout
          unblocker << :timeout
        end
        result = unblocker.pop
        consumer.cancel
        raise ::Timeout::Error if result == :timeout

        result
      end

      # Extract CN certificate attribute from certificate path
      # @param cert_path [String] path to certificate file
      # @return [String] certificate CN attribute value
      def self.commonname(cert_path)
        cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
        cert.subject.to_a.find {|name, _, _| name == 'CN' }[1]
      end

      # Set default options and create non started connection to amqp
      # @option options [String] :hosts List of Amqp hosts (default MQ_HOST env variable or mq)
      # @option options [String] :hostname Amqp host (default MQ_HOST env variable or mq)
      # @option options [Integer] :port Amqp port (default MQ_PORT env variable or 5671 - default tls port)
      # @option options [String] :vhost Connected amqp virtual host (default MQ_VHOST env variable or /)
      # @option options [Boolean] :tls Use tls (default true)
      # @option options [String] :tls_cert Path to certificate file (default config/keys/cert.pem)
      # @option options [String] :tls_key Path to key file (default config/keys/key.pem)
      # @option options [Array] :tls_ca_certificates List to ca certificates (default config/keys/cacert.pem)
      # @option options [String] :verify Verification option server certificate *
      # @option options [String] :verify_peer Verification option server certificate *
      # @option options [String] :verify_ssl Verification option server certificate *
      # @option options [String] :auth_mechanism Amqp authorization mechanism (default EXTERNAL)
      # @option options [Boolean] :automatically_recover Allow automatic network failure recovery (default false)
      # @option options [Boolean] :automatic_recovery Alias for automatically_recover (default false)
      # @option options [Integer] :recovery_attempts  Limits the number of connection recovery attempts performed by Bunny (default 0, nil - unlimited)
      # @option options [Boolean] :recover_from_connection_close (default false)
      # @return [Bunny::Session] non started amqp connection
      def self.create_connection(options = {})
        hosts = [options[:hosts] || options[:host] || options[:hostname]].flatten.select(&:present?).uniq
        hosts = hosts.map{|h| h.split(/[;|]/) }.flatten.select(&:present?).uniq

        options[:hosts] = if hosts.empty?
          [ENV.fetch('MQ_HOST', 'mq')].split(/[;|]/).flatten.select(&:present?).uniq
        else
          hosts
        end

        options[:port] ||= ENV['MQ_PORT'] || 5671
        options[:vhost] ||= ENV['MQ_VHOST'] || '/'
        user = options[:username] || options[:user] || ENV['MQ_USER']
        options[:username] = options[:user] = user

        # Передаем пустую строку чтобы bunny не использовал пароль по умолчанию guest
        pwd = options[:password] || options[:pass] || options[:pwd] || ENV['MQ_PASS'] || ''
        options[:password] = options[:pass] = options[:pwd] = pwd

        options[:tls] = options.fetch(:tls, true)
        options[:tls_cert] ||= 'config/keys/cert.pem'
        options[:tls_key] ||= 'config/keys/key.pem'
        options[:tls_ca_certificates] ||= ['config/keys/cacert.pem']

        options[:verify] =
          options.fetch(:verify, options.fetch(:verify_peer, options.fetch(:verify_ssl, nil)))
        options[:verify] = true if options[:verify]
        options[:verify_peer] = options[:verify]
        options[:verify_ssl] = options[:verify]

        options[:auth_mechanism] ||= if options[:tls]
          'EXTERNAL'
        else
          'PLAIN'
        end

        options[:automatically_recover] ||= false
        options[:automatic_recovery]    ||= false
        options[:recovery_attempts]     ||= 0
        options[:recover_attempts] = options[:recovery_attempts]
        options[:recover_from_connection_close] ||= false
        Bunny.new(options)
      end

    end
  end
end

