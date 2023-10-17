module X
  # Base error class
  class Error < ::StandardError
    def initialize(msg, _response = {})
      super(msg)
    end
  end
end
