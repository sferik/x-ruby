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
  access_token:        "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE",
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

## History and Philosophy

This library is a rewrite of the [Twitter Ruby library](https://github.com/sferik/twitter). Over 16 years, that library ballooned to over 3,000 lines of code (plus 7,500 lines of tests). At the time of writing, this library is about 300 lines of code (plus 200 test lines) and I’d like to keep it that way. That doesn’t mean new features won’t be added over time, but the benefits of potential new features must be weighed against the benefits of simplicity:

* Less code is easier to maintain.
* Less code means fewer bugs.
* Less code runs faster.

In the immortal words of [Ezra Zygmuntowicz](https://github.com/ezmobius) and his [Merb](https://github.com/merb) project (may they both rest in peace): “No code is faster than no code.” The fastest code is the code that is never executed because it doesn’t exist. That principle should apply not just to this library itself but to third-party dependencies. At present, this library has one dependency ([oauth](https://rubygems.org/gems/oauth)) and I’d like to keep it that way. If anything, it should have fewer.

The tests for the previous version of this library ran in about 2 seconds. That sounds pretty fast until you see that tests for this library run in 2 hundredths of a second. This means you can automatically run the tests any time you write a file and receive immediate feedback. For such of workflows, 2 seconds feels painfully slow. At the same time, we aim to maintain 100% C0 code coverage.

This code is not littered with comments that are intended to generate documentation. Rather, this code is intended to be simple enough to serve as its own documentation. If you want to understand how something works, don’t read the documentation—it might be wrong—just read the code. The code is always right.

This project conforms to [Standard Ruby](https://github.com/standardrb/standard). Patches that don’t maintain that standard will not be accepted.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sferik/x.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
