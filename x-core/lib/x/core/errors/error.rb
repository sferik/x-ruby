module X
  # Base error class for all X API errors
  #
  # x-objects defines the same class in lib/x/objects/errors.rb, since it does not depend on x-core; keep the two the same
  class Error < StandardError; end
end
