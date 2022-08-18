# frozen_string_literal: true

require_relative 'lib/bbk/amqp/version'

Gem::Specification.new do |spec|
  spec.name          = 'bbk-amqp'
  spec.version       = ENV['BUILDVERSION'].to_i.positive? ? "#{BBK::AMQP::VERSION}.#{ENV['BUILDVERSION'].to_i}" : BBK::AMQP::VERSION
  spec.authors       = ['Samoylenko Yuri']
  spec.email         = ['kinnalru@gmail.com']

  spec.summary       = 'AMQP interaction classes for BBK stack'
  spec.description   = 'AMQP interaction classes for BBK stack'

  spec.files         = Dir['bin/*', 'lib/**/*', 'sig/**/*', 'Gemfile*', 'LICENSE.txt', 'README.md']
  spec.bindir        = 'bin'
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '>= 6.0'
  spec.add_runtime_dependency 'bbk-utils', '> 1.0.1'
  spec.add_runtime_dependency 'bunny', '>= 2.19.0'
  spec.add_runtime_dependency 'oj'

  spec.add_development_dependency 'bbk-app', '>= 1.0.0'
  spec.add_development_dependency 'bunny-mock'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rubycritic'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-console'
end

