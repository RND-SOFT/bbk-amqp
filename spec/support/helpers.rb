# frozen_string_literal: true

Dir.glob(File.join(__dir__, 'helpers', '*.rb')).sort.each do |r|
  require r
end

RSpec.configure do |config|
  config.include RandomHash
  config.include GenerateCert
end
