# frozen_string_literal: true

RSpec.describe Aggredator::AMQP::Domains do
  it 'default' do
    domains = described_class.default
    expect(domains['outer']).to eq ''
    expect(domains['direct']).to eq ''
    expect(domains['inner']).to eq 'main_exchange'
    expect(domains['gw']).to eq 'gw'
    expect(domains[Aggredator::Dispatcher::ANSWER_DOMAIN]).to eq ''
  end

  it '#each' do
    obj = described_class.new a: 'first', b: 'second'
    expect(obj.each.map.to_h).to eq({ 'a' => 'first', 'b' => 'second'})
  end

  it '#has?' do
    obj = described_class.new a: SecureRandom.uuid
    expect(obj.has?(:a)).to be_truthy
    expect(obj.has?(:b)).to be_falsey
  end
end

