# X

A Ruby interface to the X API.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add x

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install x

## Usage

```ruby
x_oauth_credentials = {
  api_key:             "INSERT YOUR X API KEY HERE",
  api_key_secret:      "INSERT YOUR X API KEY SECRET HERE",
  access_token:        "INSERT YOUR X API ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X API ACCESS TOKEN SECRET HERE",
}

# Initialize X API client with OAuth credentials
x_client = X::Client.new(**x_oauth_credentials)

# Request yourself
x_client.get("users/me")
# {"data"=>{"id"=>"7505382", "name"=>"Erik Berlin", "username"=>"sferik"}}

# Post a tweet
tweet = x_client.post("tweets", '{"text":"Hello, World! (from @gem)"}')
# {"data"=>{"edit_history_tweet_ids"=>["1234567890123456789"], "id"=>"1234567890123456789", "text"=>"Hello, World! (from @gem)"}}

# Delete a tweet
x_client.delete("tweets/#{tweet["data"]["id"]}")
# {"data"=>{"deleted"=>true}}

# Initialize an API v1.1 client
v1_client = X::Client.new(base_url: "https://api.twitter.com/1.1/", **x_oauth_credentials)

# Request your account settings
v1_client.get("account/settings.json")

# Initialize an X Ads API client
ads_client = X::Client.new(base_url: "https://ads-api.twitter.com/12/", **x_oauth_credentials)

# Request your ad accounts
ads_client.get("accounts")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sferik/x.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
