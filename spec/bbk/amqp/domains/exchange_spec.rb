RSpec.describe BBK::AMQP::Domains::Exchange do
  let(:exchange) { SecureRandom.hex }
  let(:routing_key) { SecureRandom.hex }
  subject { described_class.new SecureRandom.hex, exchange }

  it '#call' do
    route_info = subject.call(BBK::App::Dispatcher::Route.new("amqp://#{subject.name}@#{routing_key}"))
    expect(route_info).is_a? described_class
    expect(route_info.exchange).to eq exchange
    expect(route_info.routing_key).to eq routing_key
  end
end

