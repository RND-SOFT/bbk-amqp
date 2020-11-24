# frozen_string_literal: true

module BunnyMock

  class Queue

    def cancel; end

  end

  class Exchange

    def on_return(&block)
      @on_return = block
      self
    end

    def call_on_return(basic_return, properties, body)
      @on_return.call(basic_return, properties, body)
    end

  end

  class Channel

    ACK_ID = 15

    def synchronize
      yield
    end

    def next_publish_seq_no
      ACK_ID
    end

    def confirm_select(callback)
      @confirm_callback = callback
    end

    def call_confirm_callback(ack_id, flag, neg)
      @confirm_callback.call(ack_id, flag, neg)
    end

  end

  class Session

    USER = 'test'

    attr_accessor :ssl_flag

    def user
      USER
    end

    def ssl?
      ssl_flag == true
    end

  end

end

