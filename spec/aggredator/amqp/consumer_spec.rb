# frozen_string_literal: true

RSpec.describe Aggredator::AMQP::Consumer do
  let(:connection) { BunnyMock.new }
  let(:queue_name) { SecureRandom.hex }
  let(:stream) { [] }
  let(:payload) { random_hash }
  let(:props) { random_hash.merge(headers: random_hash) }

  subject { described_class.new connection, queue_name }

  it '#protocols' do
    expect(subject.protocols).to eq described_class::PROTOCOLS
  end

  it '#run' do
    subject.run(stream)
    expect(stream).to be_empty
    expect(connection.queues).not_to be_empty
    queue = connection.queues.values.first
    queue.publish payload.to_json, props

    expect(stream.size).to eq 1
    msg = stream.pop
    expect(msg.headers).to include(props[:headers].with_indifferent_access)
    expect(msg.headers).to include(props.except(:headers).with_indifferent_access)
    expect(msg.properties).to eq props.with_indifferent_access
    expect(msg.delivery_info[:message_consumer]).to eq subject
    expect(msg.payload).to eq payload

    queue.publish payload, props
    expect(stream.size).to eq 1
    msg = stream.pop
    expect(msg.payload).to eq({})
    expect(msg.body).to eq payload
  end

  it '#ack' do
    subject.run(stream)
    channel = subject.instance_variable_get('@channel')
    queue = connection.queues.values.first
    queue.publish payload, props

    msg = stream.pop
    delivery_tag = msg.delivery_info[:delivery_tag]
    expect(channel).to receive(:ack).with(delivery_tag)
    subject.ack msg
  end

  it '#nack' do
    subject.run(stream)
    channel = subject.instance_variable_get('@channel')
    queue = connection.queues.values.first
    queue.publish payload, props

    msg = stream.pop
    delivery_tag = msg.delivery_info[:delivery_tag]
    expect(channel).to receive(:reject).with(delivery_tag, false)
    subject.nack msg
  end

  it '#close' do
    subject.run(stream)
    channel = subject.instance_variable_get('@channel')
    expect(channel).to receive(:close)
    subject.close
  end
end

