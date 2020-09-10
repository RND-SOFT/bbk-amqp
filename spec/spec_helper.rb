# frozen_string_literal: true

require 'bundler/setup'

require 'bunny-mock'
require 'simplecov'
require 'simplecov-console'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                 SimpleCov::Formatter::HTMLFormatter, # for gitlab
                                                                 SimpleCov::Formatter::Console # for developers
                                                               ])

SimpleCov.start do
  add_filter do |source_file|
    source_file.filename.start_with? File.join(Dir.pwd, 'spec')
  end
end

require 'aggredator/amqp'

Dir[File.join(__dir__, 'support', '**', '*.rb')].sort.each {|f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

