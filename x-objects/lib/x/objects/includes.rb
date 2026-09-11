require "monitor"
require_relative "utils"

module X
  module Objects
    # The identity map for one API response: the expanded objects it included and the stubs built for its references
    # @api private
    class Includes
      # Initialize a new identity map
      #
      # @api private
      # @param data [Hash, nil] the includes hash from an API response
      # @return [Includes] a new identity map
      def initialize(data = nil)
        @data = Utils.deep_freeze(data.to_h)
        @monitor = Monitor.new
        @index = {}
        @resources = {}
        freeze
      end

      # Resolve a reference to the included resource or a stub holding its identifier
      #
      # Every reference to the same resource within one response resolves to the same object,
      # so hydrating it once hydrates it everywhere it is referenced.
      #
      # @api private
      # @param klass [Class] the resource class
      # @param id [String] the identifier
      # @param client [Object, nil] the client used to fetch the response
      # @return [Resource] the resource
      def resolve(klass, id, client:)
        @monitor.synchronize do
          @resources[[klass, id]] ||= klass.new(index(klass).fetch(id) { {klass.id_key => id} }, client:, includes: self)
        end
      end

      private

      # Build or fetch the identifier index for one type of expanded object
      #
      # @api private
      # @param klass [Class] the resource class
      # @return [Hash{String => Hash}] the expanded objects keyed by identifier
      def index(klass)
        key = klass.includes_key
        entries = @data.fetch(key, []) #: Array[Hash[String, untyped]]
        @index[key] ||= entries.group_by { |attrs| attrs[klass.id_key] }.transform_values(&:first)
      end
    end
  end
end
