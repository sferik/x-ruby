$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "x"

require "minitest/autorun"
require "webmock/minitest"

def stub_bearer_request(method, endpoint, status)
  stub_request(method, "https://api.twitter.com/2/#{endpoint}")
    .with(headers: { "Authorization" => "Bearer #{@bearer_token}" })
    .to_return(status: status, body: {}.to_json)
end

def stub_oauth_request(method, endpoint, status)
  stub_request(method, "https://api.twitter.com/2/#{endpoint}")
    .with(headers: { "Authorization" => /OAuth/ }) # Match any Authorization header containing 'OAuth'
    .to_return(status: status, body: {}.to_json)
end
