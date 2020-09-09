Dir.glob(File.join(__dir__, 'helpers', '*.rb')).each do |r|
  require r
end

RSpec.configure do |config|
  config.include RandomHash
end
