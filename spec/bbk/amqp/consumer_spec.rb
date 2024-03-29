# frozen_string_literal: true

RSpec.describe BBK::AMQP::Consumer do
  let(:connection) { BunnyMock.new }
  let(:queue_name) { SecureRandom.hex }
  let(:stream) { BBK::App::Dispatcher::MessageStream.new }
  let(:stream_queue) { stream.queue }
  let(:payload) { random_hash }
  let(:props) { random_hash.merge(headers: random_hash) }

  subject { described_class.new connection, queue_name: queue_name }

  context '#ctor' do
    it 'pass queue_name' do
      expect{ described_class.new(connection, queue_name: queue_name) }.not_to raise_error
    end

    it 'pass queue in options' do
      expect do
        described_class.new(connection, queue: OpenStruct.new(name: :test))
      end.not_to raise_error
    end

    it 'default rejection policy is requeue' do
      expect(subject.rejection_policy).to be_a BBK::AMQP::RejectionPolicies::Requeue
    end
  end

  it '#protocols' do
    expect(subject.protocols).to eq described_class::PROTOCOLS
  end

  it '#run' do
    subject.run(stream)
    expect(stream_queue).to be_empty
    expect(connection.queues).not_to be_empty
    queue = connection.queues.values.first
    queue.publish payload.to_json, props

    expect(stream_queue.size).to eq 1
    msg = stream_queue.pop
    expect(msg.headers).to include(props[:headers].with_indifferent_access)
    expect(msg.headers).to include(props.except(:headers).with_indifferent_access)
    expect(msg.properties).to eq props.with_indifferent_access
    expect(msg.delivery_info[:message_consumer]).to eq subject
    expect(msg.payload).to eq payload

    queue.publish payload, props
    expect(stream_queue.size).to eq 1
    msg = stream_queue.pop
    expect(msg.payload).to eq({})
    expect(msg.body).to eq payload
  end

  context '#ack' do
  
    let(:channel) { double }
    let(:delivery_tag) { SecureRandom.uuid }

    let(:in_message) do
      BBK::AMQP::Message.new(OpenStruct.new(protocols: "test"), {channel: channel, delivery_tag: delivery_tag}, {}, {})
    end

    it 'without answer' do
      expect(channel).to receive(:ack).with(delivery_tag)
      subject.ack in_message
    end

    it 'answer with non configured publisher' do
      expect do
        subject.ack in_message, :message_mock
      end.to raise_error
    end

    it 'send answer' do
      expect(channel).to receive(:ack).with(delivery_tag)
      subject.publisher = double(BBK::AMQP::Publisher)
      subject.ack in_message, OpenStruct.new(route: :test)
    end

  end

  it '#stop' do
    subject.run(stream)
    subscription = subject.instance_variable_get('@subscription')
    expect(subscription).to receive(:cancel)
    subject.stop
  end

  it '#close' do
    subject.run(stream)
    channel = subject.instance_variable_get('@channel')
    expect(channel).to receive(:close)
    subject.close
  end
end

