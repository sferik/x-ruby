module X
  # Base error class
  class Error < ::StandardError
    def initialize(msg, _response = nil)
      super(msg)
    end
  end
end
