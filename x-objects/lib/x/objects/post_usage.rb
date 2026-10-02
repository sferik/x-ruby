# frozen_string_literal: true

require_relative "serialization"
require_relative "shape"
require_relative "utils"
require_relative "value_equality"
require_relative "value_marshalling"

module X
  module Objects
    # How many posts the app's project has read, as the usage endpoint reports it
    #
    # The API caps the posts a project reads each month, and bills each post read, so the usage shows both what a
    # project has spent and how much of its cap remains.
    #
    # @api public
    class ::X::PostUsage
      include Serialization
      include ValueEquality
      include ValueMarshalling

      # The endpoint that reports the post usage of the project
      ENDPOINT = "usage/tweets"
      private_constant :ENDPOINT
      # Every field of the usage
      FIELDS = %w[cap_reset_day daily_client_app_usage daily_project_usage project_cap project_id project_usage].freeze

      # The raw attributes of the usage
      # @api public
      # @return [Hash{String => Object}] the attributes
      # @example Get the raw attributes
      #   usage.attrs # => {"project_usage" => "1234", "project_cap" => "3000000", ...}
      attr_reader :attrs

      # Look up the current post usage of the project the client's app belongs to
      #
      # A project has one usage, so it is looked up by no identifier, as X::User.current looks up the one user a
      # client signs in as. The usage endpoint takes app-only authentication, so a client that signs its requests with OAuth 1.0a
      # looks the usage up with a copy that authenticates as the app.
      #
      # @api public
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters, such as days, the number of days to report, which is 7 by default
      # @return [PostUsage] the usage
      # @example Look up the usage of the last 30 days
      #   X::PostUsage.current(client: client, days: 30).project_usage
      def self.current(client:, **params)
        body = Utils.app_client(client).get(Utils.path(ENDPOINT, {"usage.fields" => FIELDS}.merge(params)), **Utils::JSON_CLASSES)
        new(body.to_h["data"].to_h)
      end

      # Initialize the usage from the attributes the API reported
      #
      # @api public
      # @param attrs [Hash{String, Symbol => Object}] the attributes
      # @return [PostUsage] a new usage
      # @raise [ArgumentError] if the attributes are not a Hash
      # @example Build a usage
      #   X::PostUsage.new({"project_usage" => "1234"})
      def initialize(attrs)
        @attrs = Utils.deep_freeze(Utils.attributes!(attrs))
        freeze
      end

      # The identifier of the project
      #
      # @api public
      # @return [Integer, nil] the identifier
      # @example Get the project identifier
      #   usage.project_id # => 1234567890
      def project_id = integer("project_id", attrs["project_id"])

      # The number of posts the project has read in the current billing cycle
      #
      # @api public
      # @return [Integer, nil] the number of posts
      # @example Get the posts read this cycle
      #   usage.project_usage # => 1234
      def project_usage = integer("project_usage", attrs["project_usage"])

      # The number of posts the project may read in a billing cycle
      #
      # @api public
      # @return [Integer, nil] the cap
      # @example Get the cap
      #   usage.project_cap # => 3000000
      def project_cap = integer("project_cap", attrs["project_cap"])

      # The day of the month the billing cycle, and so the usage, starts over
      #
      # It is an Integer whether the response holds it as a number or as a String, as it holds the other counts.
      #
      # @api public
      # @return [Integer, nil] the day of the month
      # @raise [InvalidAttribute] if the response holds a value that is not a number
      # @example Get the reset day
      #   usage.cap_reset_day # => 16
      def cap_reset_day = integer("cap_reset_day", attrs["cap_reset_day"])

      # The number of posts the project read each day
      #
      # @api public
      # @return [Hash{Time => Integer}] the number of posts, keyed by the start of each day
      # @raise [InvalidAttribute] if the response holds a day without a date in ISO 8601, or a number that is not one,
      #   or holds the days as something other than a list of objects
      # @example Get the posts read yesterday
      #   usage.daily.values.last(2).first
      def daily = days("daily", Shape.dig("#{self.class}#daily", attrs, %w[daily_project_usage usage]))

      # The number of posts each of the project's apps read each day
      #
      # @api public
      # @return [Hash{Integer, nil => Hash{Time => Integer}}] the daily usage, keyed by the identifier of each app
      # @raise [InvalidAttribute] if the response holds an app identifier that is not a number, a day without a date in
      #   ISO 8601, or a number that is not one, or holds the apps or their days as something other than a list of objects
      # @example Total the posts each app read
      #   usage.daily_by_app.transform_values { |days| days.values.sum }
      def daily_by_app
        by_app = {} #: Hash[Integer?, Hash[Time, Integer]]
        Shape.objects("#{self.class}#daily_by_app", attrs["daily_client_app_usage"]).each do |app|
          by_app[integer("daily_by_app", app["client_app_id"])] = days("daily_by_app", app["usage"])
        end
        by_app.freeze
      end

      # Deconstruct the usage into what its readers read, so it matches a hash pattern
      #
      # Only the readers a pattern names are read, so one that names the counts of the project matches a usage whose
      # days cannot be read.
      #
      # @api public
      # @param keys [Array<Symbol>, nil] the keys the pattern asks for, or nil for every reader
      # @return [Hash{Symbol => Object}] what the readers read
      # @raise [InvalidAttribute] if the pattern asks for what the response holds as something that cannot be read
      # @example Warn when the project has read nine tenths of its cap
      #   case usage in {project_usage: Integer => used, project_cap: Integer => cap} if used * 10 >= cap * 9 then warn "near the cap"
      #   end
      def deconstruct_keys(keys) = Utils.deconstruct(self, keys, %i[project_id project_usage project_cap cap_reset_day daily daily_by_app])

      private

      # Read daily usage entries, counting a day without a number as zero
      # @api private
      # @param reader [String] the name of the reader that reads them
      # @param entries [Array<Hash>, nil] the entries, each with a date and a usage
      # @return [Hash{Time => Integer}] the number of posts, keyed by the start of each day
      # @raise [InvalidAttribute] if an entry has no date in ISO 8601, or a number that is not one, or the entries are
      #   not a list of objects
      def days(reader, entries)
        counts = {} #: Hash[Time, Integer]
        entries = Shape.objects("#{self.class}##{reader}", entries)
        entries.each { |entry| counts[time(reader, entry["date"])] = integer(reader, entry["usage"]) || 0 }
        counts.freeze
      end

      # Read an identifier or a count the response holds as an Integer
      # @api private
      # @param reader [String] the name of the reader that reads it
      # @param value [String, Integer, nil] the value
      # @return [Integer, nil] the Integer, or nil if the value is missing
      # @raise [InvalidAttribute] if the value is not a number
      def integer(reader, value) = Utils.read("#{self.class}##{reader}", value) { Shape.integer(value) }

      # Read a date the response holds as a Time, which it must hold
      # @api private
      # @param reader [String] the name of the reader that reads it
      # @param value [String, nil] the date, in ISO 8601
      # @return [Time] the time
      # @raise [InvalidAttribute] if the value is missing, or is not ISO 8601
      def time(reader, value) = Utils.read("#{self.class}##{reader}", value) { Time.iso8601(value.to_s) }
    end
  end
end
