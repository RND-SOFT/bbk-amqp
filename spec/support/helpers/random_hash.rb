# frozen_string_literal: true

module RandomHash

  def random_hash(size: 10)
    size.times.map { [SecureRandom.uuid, SecureRandom.uuid] }.to_h
  end

end

