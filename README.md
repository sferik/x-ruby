# X

A Ruby interface to the X 2.0 API.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add x

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install x

## Usage

```ruby
x_api_key             = "YOUR_X_API_KEY"
x_api_key_secret      = "YOUR_X_API_KEY_SECRET"
x_access_token        = "YOUR_X_ACCESS_TOKEN"
x_access_token_secret = "YOUR_X_ACCESS_TOKEN_SECRET"

x_client = X::Client.new(api_key:             x_api_key,
                         api_key_secret:      x_api_key_secret,
                         access_token:        x_access_token,
                         access_token_secret: x_access_token_secret)

begin
  response = x_client.get("users/me")
  puts JSON.pretty_generate(response)
rescue X::Error => e
  puts "Error: #{e.message}"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sferik/x.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
