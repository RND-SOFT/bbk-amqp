# frozen_string_literal: true

RSpec.describe BBK::AMQP::Consumer do
  let(:connection) { BunnyMock.new }
  let(:queue_name) { SecureRandom.hex }
  let(:stream) { BBK::App::Dispatcher::MessageStream.new }
  let(:stream_queue) { stream.queue }
  let(:payload) { random_hash }
  let(:props) { random_hash.merge(headers: random_hash) }
  let(:publisher) { double(BBK::AMQP::Publisher) }
  let(:rejection_policy) { double }

  subject(:consumer) {   described_class.new connection, queue_name: queue_name, publisher: publisher }

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
      BBK::AMQP::Message.new(OpenStruct.new(protocols: 'test'),
                             { channel: channel, delivery_tag: delivery_tag }, {}, {})
    end

    it do
      expect(channel).to receive(:ack).with(delivery_tag)
      expect(publisher).not_to receive(:publish)

      expect{ subject.ack in_message }.not_to raise_error
    end

    context 'Send answer throug publisher' do
      let(:answer) { double(BBK::App::Dispatcher::Result, route: 'route') }
      it do
        expect(channel).to receive(:ack).with(delivery_tag)
        expect(publisher).to receive(:publish).with(answer).and_return(double(value!: true))

        expect{ subject.ack in_message, answer: answer }.not_to raise_error
      end

      context 'Without publisher' do
        let(:publisher) { nil }

        it do
          expect(channel).not_to receive(:ack).with(delivery_tag)
          expect{ subject.ack in_message, answer: answer }.to raise_error(/Publisher not configured/)
        end
      end
    end
  end

  context '#nack' do
    let(:in_message) { double(BBK::AMQP::Message) }
    subject(:consumer) do
      described_class.new connection, queue_name: queue_name, rejection_policy: rejection_policy
    end

    it {
      expect(rejection_policy).to receive(:call).with(in_message, 'error', 1, 2, a1: :a1)
      subject.nack(in_message, 1, 2, error: 'error', a1: :a1)
    }
  end

  describe '#stop' do
    before { subject.run(stream) }

    it do
      subscription = subject.instance_variable_get('@subscription')
      expect(subscription).to receive(:cancel)
      subject.stop
    end

    it { expect{ subject.stop }.to change{ subject.instance_variable_get('@subscription') }.to(nil) }
  end

  describe '#close' do
    before { subject.run(stream) }

    it do
      channel = subject.instance_variable_get('@channel')
      expect(channel).to receive(:close)
      subject.close
    end

    it { expect{ subject.close }.to change{ subject.instance_variable_get('@channel') }.to(nil) }
  end
end

