# frozen_string_literal: true

RSpec.describe Aggredator::AMQP::MutableDomains do
  subject { described_class.new }

  context 'change domain' do
    let(:domain_name) { SecureRandom.hex }
    let(:exchange) { SecureRandom.hex }

    it 'set new' do
      subject[domain_name] = exchange
      expect(subject[domain_name]).to eq exchange
    end

    it 'update' do
      subject[domain_name] = 'test'
      subject[domain_name] = exchange
      expect(subject[domain_name]).to eq exchange
    end
  end
end

