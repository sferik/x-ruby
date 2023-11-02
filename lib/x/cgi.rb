require "cgi"

module X
  class CGI
    # TODO: Replace CGI.escape with CGI.escapeURIComponent when support for Ruby 3.1 is dropped
    def self.escape(value)
      ::CGI.escape(value).gsub("+", "%20")
    end

    def self.escape_params(params)
      params.map { |k, v| "#{k}=#{escape(v)}" }.join("&")
    end
  end
end
