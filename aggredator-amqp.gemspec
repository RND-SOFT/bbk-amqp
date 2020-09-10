# frozen_string_literal: true

require_relative 'lib/aggredator/amqp/version'

Gem::Specification.new do |spec|
  spec.name          = 'aggredator-amqp'
  spec.version       = ENV['BUILDVERSION'].to_i.positive? ? "#{Aggredator::AMQP::VERSION}.#{ENV['BUILDVERSION'].to_i}" : Aggredator::AMQP::VERSION
  spec.authors       = ['Samoylenko Yuri']
  spec.email         = ['kinnalru@gmail.com']

  spec.summary       = 'Amqp library for aggredator'
  spec.description   = 'Library with consumers and publishers working with amqp for aggredator'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.files         = Dir['bin/console', 'bin/setup', 'lib/**/*', 'Gemfile*', 'LICENSE.txt', 'README.md']
  spec.bindir        = 'bin'
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport'
  # только для ANSWER_DOMAIN и возможно его стоит удалить и явно здесь прописать.
  spec.add_runtime_dependency 'aggredator-app', '~> 2.1.0' 
  spec.add_runtime_dependency 'bunny'

  spec.add_development_dependency 'aggredator-api'
  spec.add_development_dependency 'bunny-mock'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rubycritic'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-console'
end

