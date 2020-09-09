require 'bunny'
require 'openssl'
require 'tempfile'

RSpec.describe Aggredator::AMQP::Utils do

  def generate_ceritificate(cn)
    subject = "/CN=#{cn}/"
    key = OpenSSL::PKey::RSA.new(4096)
    cert = OpenSSL::X509::Certificate.new
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
    cert.not_before = Time.now
    cert.not_after = Time.now + 1.hour
    cert.public_key = key.public_key
    cert.sign key, OpenSSL::Digest::SHA1.new
    cert
  end

  context 'pop message' do

    let(:connection) { BunnyMock.new }
    let(:channel) { connection.channel } 
    let(:queue) { channel.queue }

    it 'timeout error'  do
      expect {
        described_class.pop queue, 1
      }.to raise_error(Timeout::Error)
    end

    it 'got json answer' do
      payload = random_hash.with_indifferent_access
      queue.publish payload.to_json
      result = described_class.pop queue, 1
      expect(result).to be_a Array
      expect(result.size).to eq 3
      expect(result.last).to eq payload
    end

    it 'got invalid not json formatted payload' do
      payload = random_hash
      queue.publish payload
      result = described_class.pop queue, 1
      expect(result).to be_a Array
      expect(result.size).to eq 3
      expect(result.last).to eq payload
    end

  end

  it '#commonname' do
    cn = SecureRandom.hex
    cert = generate_ceritificate(cn)
    tf = Tempfile.new
    tf.write cert.to_pem
    tf.flush
    expect(described_class.commonname(tf.path)).to eq cn
  end

  it '#create_connection' do
    expect(Bunny).to receive(:new)
    described_class.create_connection
  end

end