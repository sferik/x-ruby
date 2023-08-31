# X

#### A Ruby interface to the X API.

## Installation

Install the gem and add to the application's Gemfile:

    bundle add x

Or, if Bundler is not being used to manage dependencies:

    gem install x

## Usage

First, obtain X credentails from https://developer.x.com.

```ruby
x_credentials = {
  api_key:             "INSERT YOUR X API KEY HERE",
  api_key_secret:      "INSERT YOUR X API KEY SECRET HERE",
  access_token:        "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE",
}

# Initialize an X API client with your OAuth credentials
x_client = X::Client.new(**x_credentials)

# Get data about yourself
x_client.get("users/me")
# {"data"=>{"id"=>"7505382", "name"=>"Erik Berlin", "username"=>"sferik"}}

# Post a tweet
tweet = x_client.post("tweets", '{"text":"Hello, World! (from @gem)"}')
# {"data"=>{"edit_history_tweet_ids"=>["1234567890123456789"], "id"=>"1234567890123456789", "text"=>"Hello, World! (from @gem)"}}

# Delete the tweet you just posted
x_client.delete("tweets/#{tweet["data"]["id"]}")
# {"data"=>{"deleted"=>true}}

# Initialize an API v1.1 client
v1_client = X::Client.new(base_url: "https://api.twitter.com/1.1/", **x_credentials)

# Request your account settings
v1_client.get("account/settings.json")

# Initialize an X Ads API client
ads_client = X::Client.new(base_url: "https://ads-api.twitter.com/12/", **x_credentials)

# Request your ad accounts
ads_client.get("accounts")
```

## History and Philosophy

This library is a rewrite of the [Twitter Ruby library](https://github.com/sferik/twitter). Over 16 years of development, that library ballooned to over 3,000 lines of code (plus 7,500 lines of tests). At the time of writing, this library is about 300 lines of code (plus 200 test lines) and I’d like to keep it that way. That doesn’t mean new features won’t be added over time, but the benefits of more code must be weighted against the benefits of less:

* Less code is easier to maintain.
* Less code means fewer bugs.
* Less code runs faster.

In the immortal words of [Ezra Zygmuntowicz](https://github.com/ezmobius) and his [Merb](https://github.com/merb) project (may they both rest in peace):

> No code is faster than no code.

The fastest code is the code that is never executed because it doesn’t exist. That principle should apply not just to this library itself but to third-party dependencies. At present, this library has one runtime dependency ([oauth](https://rubygems.org/gems/oauth)) and I’d like to keep it that way. If anything, it should have fewer dependencies.

Tests for the previous version of this library ran in about 2 seconds. That sounds pretty fast until you see that tests for this library run in 2 hundredths of a second. This means you can automatically run the tests any time you write a file and receive immediate feedback. For such of workflows, 2 seconds feels painfully slow.

This code is not littered with comments that are intended to generate documentation. Rather, this code is intended to be simple enough to serve as its own documentation. If you want to understand how something works, don’t read the documentation—it might be wrong—read the code. The code is always right.

## Development

1. Checkout and repo:

       git checkout git@github.com:sferik/x-ruby.git

2. Enter the repo’s directory:

       cd x-ruby

3. Install dependencies via Bundler:

       bin/setup

4. Run the default Rake task to ensure all tests pass:

       bundle exec rake

5. Create a new branch for your feature or bug fix:

       git checkout -b my-new-branch

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sferik/x-ruby.

Pull requests will only be accepted if they meet all the following criteria:

1. Code must conform to [Standard Ruby](https://github.com/standardrb/standard). This can be verified with:

       bundle exec rake standard

2. For any new code paths, tests must be added to maintain 100% C0 code coverage. This can be verified with:

       bundle exec rake test

3. For any new classes or methods, RBS type signatures must be added (to sig/x.rbs). This can be verified with:

       bundle exec rake steep

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
