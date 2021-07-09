# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'oj'

require 'aggredator/app'
require 'aggredator/amqp/version'
require 'aggredator/amqp/proxy_logger'
require 'aggredator/amqp/utils'
require 'aggredator/amqp/message'
require 'aggredator/amqp/domains'
require 'aggredator/amqp/mutable_domains'
require 'aggredator/amqp/publisher'
require 'aggredator/amqp/consumer'
require_relative 'bunny_patch'

module Aggredator
  module AMQP

    class << self

      attr_accessor :logger

    end

    self.logger = ::Logger.new(STDOUT)

  end
end

