module X
  module Uploader
    # The classes the uploaders parse responses into, whatever parsing classes a client defaults to
    #
    # The uploaders read the responses they receive, and return them, as Hashes and Arrays, so a client whose
    # default_object_class is another class, such as OpenStruct, still uploads.
    #
    # @api private
    JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze
    private_constant :JSON_CLASSES
  end
end
