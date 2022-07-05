# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'oj'
require 'bbk/utils'
require 'bbk/amqp/version'
require 'bbk/amqp/utils'
require 'bbk/amqp/message'
require 'bbk/amqp/publisher'
require 'bbk/amqp/consumer'
require 'bbk/amqp/route_info'
require 'bbk/amqp/domains_set'
require 'bbk/amqp/domains/exchange'
require 'bbk/amqp/domains/by_block'
require 'bbk/amqp/rejection_policies/reject'
require 'bbk/amqp/rejection_policies/requeue'
require 'bbk/amqp/rejection_policies/republish'
require_relative 'bunny_patch'


module BBK
  module AMQP

    class << self

      attr_accessor :logger

    end

    self.logger = ::BBK::Utils::Logger.default

  end
end

