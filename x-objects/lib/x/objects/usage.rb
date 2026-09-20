require_relative "serialization"
require_relative "utils"

module X
  # How many posts the app's project has read, as the usage endpoint reports it
  #
  # The API caps the posts a project reads each month, and bills each post read, so the usage shows both what a
  # project has spent and how much of its cap remains.
  #
  # @api public
  class Usage
    include Objects::Serialization

    # The endpoint that reports the post usage of the project
    ENDPOINT = "usage/tweets".freeze
    # Every field of the usage
    FIELDS = %w[cap_reset_day daily_client_app_usage daily_project_usage project_cap project_id project_usage].freeze

    # The raw attributes of the usage
    # @api public
    # @return [Hash{String => Object}] the attributes
    # @example Get the raw attributes
    #   usage.attrs # => {"project_usage" => "1234", "project_cap" => "3000000", ...}
    attr_reader :attrs

    # @!method to_h
    #   Alias for attrs, returns the raw attributes
    #   @api public
    #   @return [Hash{String => Object}] the attributes
    #   @example Convert the usage to a hash
    #     usage.to_h
    alias_method :to_h, :attrs

    # Look up the post usage of the project the client's app belongs to
    #
    # The usage endpoint takes app-only authentication, so a client that signs its requests with OAuth 1.0a
    # looks the usage up with a copy that authenticates as the app.
    #
    # @api public
    # @param client [Object] the client used to make the request
    # @param params [Hash] query parameters, such as days, the number of days to report, which is 7 by default
    # @return [Usage] the usage
    # @example Look up the usage of the last 30 days
    #   X::Usage.find(client: client, days: 30).project_usage
    def self.find(client:, **params)
      body = Objects::Utils.app_client(client).get(Objects::Utils.path(ENDPOINT, {"usage.fields" => FIELDS}.merge(params)), **Objects::Utils::JSON_CLASSES)
      new(body.to_h["data"].to_h)
    end

    # Initialize the usage from the attributes the API reported
    #
    # @api public
    # @param attrs [Hash{String => Object}] the attributes
    # @return [Usage] a new usage
    # @example Build a usage
    #   X::Usage.new({"project_usage" => "1234"})
    def initialize(attrs)
      @attrs = Objects::Utils.deep_freeze(attrs)
      freeze
    end

    # The identifier of the project
    #
    # @api public
    # @return [Integer, nil] the identifier
    # @example Get the project identifier
    #   usage.project_id # => 1234567890
    def project_id = Objects::Utils.integer(attrs["project_id"])

    # The number of posts the project has read in the current billing cycle
    #
    # @api public
    # @return [Integer, nil] the number of posts
    # @example Get the posts read this cycle
    #   usage.project_usage # => 1234
    def project_usage = Objects::Utils.integer(attrs["project_usage"])

    # The number of posts the project may read in a billing cycle
    #
    # @api public
    # @return [Integer, nil] the cap
    # @example Get the cap
    #   usage.project_cap # => 3000000
    def project_cap = Objects::Utils.integer(attrs["project_cap"])

    # The day of the month the billing cycle, and so the usage, starts over
    #
    # @api public
    # @return [Integer, nil] the day of the month
    # @example Get the reset day
    #   usage.cap_reset_day # => 16
    def cap_reset_day = attrs["cap_reset_day"]

    # The number of posts the project read each day
    #
    # @api public
    # @return [Hash{Time => Integer}] the number of posts, keyed by the start of each day
    # @example Get the posts read yesterday
    #   usage.daily.values.last(2).first
    def daily = days(attrs.dig("daily_project_usage", "usage"))

    # The number of posts each of the project's apps read each day
    #
    # @api public
    # @return [Hash{Integer, nil => Hash{Time => Integer}}] the daily usage, keyed by the identifier of each app
    # @example Total the posts each app read
    #   usage.daily_by_app.transform_values { |days| days.values.sum }
    def daily_by_app
      by_app = {} #: Hash[Integer?, Hash[Time?, Integer]]
      apps = Array(attrs["daily_client_app_usage"]) #: Array[Hash[String, untyped]]
      apps.each { |app| by_app[Objects::Utils.integer(app["client_app_id"])] = days(app["usage"]) }
      by_app.freeze
    end

    private

    # Read daily usage entries, counting a day without a number as zero
    # @api private
    # @param entries [Array<Hash>, nil] the entries, each with a date and a usage
    # @return [Hash{Time => Integer}] the number of posts, keyed by the start of each day
    def days(entries)
      counts = {} #: Hash[Time?, Integer]
      entries = Array(entries) #: Array[Hash[String, untyped]]
      entries.each { |entry| counts[Objects::Utils.time(entry.fetch("date"))] = Objects::Utils.integer(entry["usage"]) || 0 }
      counts.freeze
    end
  end
end
