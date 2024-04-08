![Tests](https://github.com/sferik/x-ruby/actions/workflows/test.yml/badge.svg)
![Linter](https://github.com/sferik/x-ruby/actions/workflows/lint.yml/badge.svg)
![Mutant](https://github.com/sferik/x-ruby/actions/workflows/mutant.yml/badge.svg)
![Typer Checker](https://github.com/sferik/x-ruby/actions/workflows/type_check.yml/badge.svg)
[![Gem Version](https://badge.fury.io/rb/x.svg)](https://rubygems.org/gems/x)

# A [Ruby](https://www.ruby-lang.org) interface to the [X API](https://developer.x.com)

## Follow

For updates and announcements, follow [this gem](https://x.com/gem) and [its creator](https://x.com/sferik) on X.

## Installation

Install the gem and add to the application's Gemfile:

    bundle add x

Or, if Bundler is not being used to manage dependencies:

    gem install x

## Usage

First, obtain X credentails from <https://developer.x.com>.

```ruby
require "x"

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

# Post
post = x_client.post("tweets", '{"text":"Hello, World! (from @gem)"}')
# {"data"=>{"edit_history_tweet_ids"=>["1234567890123456789"], "id"=>"1234567890123456789", "text"=>"Hello, World! (from @gem)"}}

# Delete the post
x_client.delete("tweets/#{post["data"]["id"]}")
# {"data"=>{"deleted"=>true}}

# Initialize an API v1.1 client
v1_client = X::Client.new(base_url: "https://api.twitter.com/1.1/", **x_credentials)

# Get your account settings
v1_client.get("account/settings.json")

# Initialize an X Ads API client
ads_client = X::Client.new(base_url: "https://ads-api.twitter.com/12/", **x_credentials)

# Get your ad accounts
ads_client.get("accounts")
```

See other common usage [examples](https://github.com/sferik/x-ruby/tree/main/examples).

## History and Philosophy

This library is a rewrite of the [Twitter Ruby library](https://github.com/sferik/twitter). Over 16 years of development, that library ballooned to over 3,000 lines of code (plus 7,500 lines of tests), not counting dependencies. This library is about 500 lines of code (plus 1000 test lines) and has no runtime dependencies. That doesn’t mean new features won’t be added over time, but the benefits of more code must be weighed against the benefits of less:

* Less code is easier to maintain.
* Less code means fewer bugs.
* Less code runs faster.

In the immortal words of [Ezra Zygmuntowicz](https://github.com/ezmobius) and his [Merb](https://github.com/merb) project (may they both rest in peace):

> No code is faster than no code.

The tests for the previous version of this library executed in about 2 seconds. That sounds pretty fast until you see that tests for this library run in one-twentieth of a second. This means you can automatically run the tests any time you write a file and receive immediate feedback. For such of workflows, 2 seconds feels painfully slow.

This code is not littered with comments that are intended to generate documentation. Rather, this code is intended to be simple enough to serve as its own documentation. If you want to understand how something works, don’t read the documentation—it might be wrong—read the code. The code is always right.

## Sponsorship

The X gem is free to use, but with X API pricing tiers, it actually costs money to develop and maintain. By contributing to the project, you help us:

1. Maintain the library: Keeping it up-to-date and secure.
2. Add new features: Enhancements that make your life easier.
3. Provide support: Faster responses to issues and feature requests.

⭐️ Bonus: Sponsors will get priority support and influence over the project roadmap. We will also list your name or your company's logo on our GitHub page.

Building and maintaining an open-source project like this takes a considerable amount of time and effort. Your sponsorship can help sustain this project. Even a small monthly donation makes a huge difference!

[Click here to sponsor this project.](https://github.com/sponsors/sferik)

## Sponsors

Many thanks to our sponsors (listed in order of when they sponsored this project):

<a href="https://betterstack.com"><img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/better_stack.svg" alt="Better Stack" width="200" align="middle"></a>
<img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/spacer.png" width="20" align="middle">
<a href="https://sentry.io"><img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/sentry.svg" alt="Sentry" width="200" align="middle"></a>
<img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/spacer.png" width="20" align="middle">
<a href="https://ifttt.com"><img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/ifttt.svg" alt="IFTTT" width="200" align="middle"></a>

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

2. 100% C0 code coverage. This can be verified with:

       bundle exec rake test

3. 100% mutation coverage. This can be verified with:

       bundle exec rake mutant

4. RBS type signatures (in `sig/x.rbs`). This can be verified with:

       bundle exec rake steep

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
