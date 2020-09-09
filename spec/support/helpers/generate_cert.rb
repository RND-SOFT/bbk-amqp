# frozen_string_literal: true

module GenerateCert
  def generate_certificate(cn)
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
end
