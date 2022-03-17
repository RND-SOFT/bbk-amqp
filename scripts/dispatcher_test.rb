#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bbk/app'
require 'bbk/amqp'

QUEUE_NAME = 'source'
ROUTE_DOMAIN = 'routing_domain'

class Processor < BBK::App::Processors::Base

  def self.rule
    [:meta, {}]
  end

  def process(message, results: [])
    logger.info "Get message #{message.inspect}"
    sleep 1
    results << BBK::App::Dispatcher::Result.new("mq://#{ROUTE_DOMAIN}@#{QUEUE_NAME}",
                                                OpenStruct.new(headers: {}, payload: { data: SecureRandom.hex }))
  end

end

logger = Logger.new STDOUT

conn_options = {
  host:  'mq',
  port:  5672,
  vhost: '/',
  user:  'user',
  pass:  'pass',
  tls:   false
}

connection = BBK::AMQP::Utils.create_connection conn_options
connection.start

ch = connection.channel
ch.queue(QUEUE_NAME, exclusive: true)

handler = BBK::App::Handler.new
handler.register Processor, logger

dispatcher = BBK::App::Dispatcher.new handler, logger: logger

consumer = BBK::AMQP::Consumer.new connection, queue_name: QUEUE_NAME, consumer_tag: 'agg_amqp_test', rejection_policy: BBK::AMQP::RejectionPolicies::Requeue.new
publisher = BBK::AMQP::Publisher.new connection,
                                     BBK::AMQP::DomainsSet.new(BBK::AMQP::Domains::Exchange.new(
                                                                 ROUTE_DOMAIN, ''
                                                               ))
publisher.raw_publish QUEUE_NAME, exchange: '', headers: { h1: 123 }, payload: { a: 1 }

dispatcher.register_consumer consumer
dispatcher.register_publisher publisher
dispatcher.run

