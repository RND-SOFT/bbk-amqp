require 'bbk/app/spec/shared/dispatcher/message'

RSpec.describe BBK::AMQP::Message do
  include_examples 'BBK::App::Dispatcher::Message' do
    let(:consumer){ double(BBK::AMQP::Consumer, protocols: [:http]) }
    let(:properties){ { headers: headers } }
    subject(:message) { described_class.new(consumer, delivery_info, properties, body) }

    describe 'methods' do
      it { is_expected.to have_attributes(message_id: headers[:message_id]) }
      it { is_expected.to have_attributes(reply_to: headers[:reply_to]) }
      it { is_expected.to have_attributes(user_id: headers[:user_id]) }
      it { is_expected.to have_attributes(protocol: :http) }
    end

    describe '#clone' do
      subject(:clone){ message.clone }

      it { is_expected.to be_a(described_class) }
      it { expect(clone.object_id).not_to eq(message.object_id) }
      it { is_expected.to have_attributes(to_h: message.to_h) }
    end

    describe 'AMQP Properties and Headers priority' do
      subject(:actual_id){ message.message_id }
      let(:message) { described_class.new(consumer, {}, @properties, '{}') }

      it {
        headers = { message_id: 'header_id' }
        @properties = { headers: headers }
        expect(actual_id).to eq('header_id')
      }

      it {
        headers = {}
        @properties = { headers: headers, message_id: 'property_id' }
        expect(actual_id).to eq('property_id')
      }
      it {
        headers = { message_id: 'header_id' }
        @properties = { headers: headers, message_id: 'property_id' }
        expect(actual_id).to eq('header_id')
      }
    end
  end
end

