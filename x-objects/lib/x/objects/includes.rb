require "monitor"
require_relative "utils"

module X
  module Objects
    # The context of one API response: its identity map of expanded objects and stubs, and the problems it reported
    # @api private
    class Includes
      # Initialize a new identity map
      #
      # @api private
      # @param data [Hash, nil] the includes hash from an API response
      # @param problems [Array<Problem>] the problems the response reported
      # @return [Includes] a new identity map
      def initialize(data = nil, problems: [])
        @data = Utils.deep_freeze(data.to_h)
        @problems = problems.freeze
        @monitor = Monitor.new
        @index = {}
        @resources = {}
        freeze
      end

      # The problems the response reported, such as missing expanded resources
      # @api private
      # @return [Array<Problem>] the problems
      attr_reader :problems

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
