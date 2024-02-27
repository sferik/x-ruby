require "cgi"

module X
  class CGI
    # TODO: Replace CGI.escape with CGI.escapeURIComponent when support for Ruby 3.1 is dropped
    def self.escape(value)
      ::CGI.escape(value).gsub("+", "%20")
    end
  end
end
