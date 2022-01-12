require 'bunny'
require 'fileutils'
require 'bbk/amqp/utils'

module BBK
  module AMQP
    module Spec
      module RabbitHelper

        cattr_accessor :mq_defaults

        def self.prepare_certs(fixtures_path)
          FileUtils.mkdir_p File.join(fixtures_path, 'keys')

          cert_path = File.join(fixtures_path, 'keys', 'cert.pem')
          key_path = File.join(fixtures_path, 'keys', 'key.pem')
          cacert_path = File.join(fixtures_path, 'keys', 'cacert.pem')

          {
            'TEST_CLIENT_CERT' => cert_path,
            'TEST_CLIENT_KEY'  => key_path,
            'CA_CERT'          => cacert_path
          }.each_pair do |env, file|
            File.write(file, ENV[env]) if ENV[env].present?
          end

          [cert_path, key_path, cacert_path]
        end

        def self.included(_mod)
          cert_path, key_path, cacert_path = prepare_certs(File.join($root, 'fixtures'))

          self.mq_defaults = {
            host:                          ENV['MQ_HOST'] || 'mq',
            port:                          ENV['MQ_PORT'] || 5671,
            tls:                           true,
            tls_cert:                      cert_path,
            tls_key:                       key_path,
            tls_ca_certificates:           [cacert_path],
            verify_peer:                   false,
            verify_ssl:                    false,
            verify:                        false,
            auth_mechanism:                'EXTERNAL',
            automatically_recover:         false,
            automatic_recovery:            false,
            recover_from_connection_close: false,
            continuation_timeout:          10_000,
            heartbeat:                     10
          }
        end

        def commonname
          BBK::AMQP::Utils.commonname(mq_defaults[:tls_cert])
        end

        def mq_connection(options = {})
          Bunny.new(mq_defaults.merge(options))
        end

        def mq_pop(queue, timeout = 10)
          BBK::AMQP::Utils.pop queue, timeout
        end

      end
    end
  end
end

