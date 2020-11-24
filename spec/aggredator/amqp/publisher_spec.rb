# frozen_string_literal: true

require 'aggredator/app'

RSpec.describe Aggredator::AMQP::Publisher do
  let(:connection) { BunnyMock.new }
  let(:domains) { Aggredator::AMQP::Domains.default }
  let(:pub_message) { Aggredator::Api::V1::Message.new({}) }

  subject { described_class.new connection, domains }

  it '#ctor' do
    obj = described_class.new(connection, domains)
    expect(obj.connection).to eq connection
    expect(obj.channel).not_to be_nil
    expect(obj.domains).to eq domains
    expect(obj.ack_map).not_to be_nil
    expect(obj.sended_messages).not_to be_nil
  end

  it '#protocols' do
    expect(subject.protocols).to eq described_class::PROTOCOLS
  end

  it '#close' do
    expect(subject.channel).to receive(:close)
    subject.close
  end

  # #publish_message called from publish message
  context '#publish' do
    it 'unsupported protocol' do
      result = Aggredator::Dispatcher::Result.new('test://example.com', nil)
      expect do
        subject.publish result
      end.to raise_error(/Unsupported protocol/)
    end

    it 'unknown domain' do
      result = Aggredator::Dispatcher::Result.new("mq://#{SecureRandom.hex}@example.com", nil)
      expect do
        subject.publish result
      end.to raise_error(/Unknown domain/)
    end

    context 'confirmation publish' do
      it 'success publishing' do
        result = Aggredator::Dispatcher::Result.new('mq://direct@example', pub_message)
        future = subject.publish result
        expect(future).not_to be_resolved
        expect(subject.ack_map).not_to be_empty
        expect(subject.sended_messages).not_to be_empty

        subject.channel.call_confirm_callback(subject.channel.class::ACK_ID, nil, false)
        expect(future).to be_resolved
        expect(future).to be_fulfilled
      end

      it 'publish confirmation neg' do
        result = Aggredator::Dispatcher::Result.new('mq://direct@example', pub_message)
        future = subject.publish result
        expect(future).not_to be_resolved

        subject.channel.call_confirm_callback(subject.channel.class::ACK_ID, nil, true)
        expect(future).to be_resolved
        expect(future).to be_rejected
      end

      it 'confirmation error' do
        result = Aggredator::Dispatcher::Result.new('mq://direct@example', pub_message)
        future = subject.publish result
        expect(future).to receive(:fulfill).and_raise('test')
        expect(subject.logger).to receive(:error)
        subject.channel.call_confirm_callback(subject.channel.class::ACK_ID, nil, false)
      end
    end

    context 'return publishing' do
      it 'returned message' do
        result = Aggredator::Dispatcher::Result.new('mq://direct@example', pub_message)
        future = subject.publish result
        exchange = connection.exchanges.values.last
        exchange.call_on_return nil, { message_id: subject.ack_map.values.first }, nil
        expect(future).to be_resolved
        expect(future).to be_rejected
      end

      it 'returned error' do
        result = Aggredator::Dispatcher::Result.new('mq://direct@example', pub_message)
        future = subject.publish result
        exchange = connection.exchanges.values.last
        expect(future).to receive(:reject).and_raise('test')
        expect(subject.logger).to receive(:error)
        exchange.call_on_return nil, { message_id: subject.ack_map.values.first }, nil
      end
    end
  end

  it '#raw_publish' do
    props = random_hash
    headers = random_hash
    payload = random_hash
    routing_key = SecureRandom.hex
    expect(subject).to receive(:send_message).and_call_original
    future = subject.raw_publish routing_key, exchange: '', properties: props, headers: headers, payload: payload
    expect(future).not_to be_resolved
  end

  context '#client_name' do
    it 'ssl' do
      connection.ssl_flag = true
      cn = SecureRandom.hex
      f = Tempfile.new
      f.write generate_certificate(cn).to_pem
      f.flush
      transport = OpenStruct.new tls_certificate_path: f.path
      expect(connection).to receive(:transport).and_return(transport)
      expect(subject.send(:client_name)).to eq cn
    end

    it 'without ssl' do
      expect(subject.send(:client_name)).to eq connection.class::USER
    end
  end
end

