module Bunny
  class Transport

    def host
      @opts[:server_name] || @host
    end

  end
end

