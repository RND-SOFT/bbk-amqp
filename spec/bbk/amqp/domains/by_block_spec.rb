RSpec.describe BBK::AMQP::Domains::ByBlock do
  let(:exchange) { SecureRandom.hex }
  let(:routing_key) { SecureRandom.hex }
  subject do
    described_class.new(SecureRandom.hex) do |_route|
      BBK::AMQP::RouteInfo.new(exchange, routing_key)
    end
  end

  it '#call' do
    route_info = subject.call(BBK::App::Dispatcher::Route.new('amqp://test'))
    expect(route_info).to be_a BBK::AMQP::RouteInfo
    expect(route_info.exchange).to eq exchange
    expect(route_info.routing_key).to eq routing_key
  end
end

