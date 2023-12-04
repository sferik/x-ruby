require "cgi"

module X
  class CGI
    def self.escape(value)
      ::CGI.escapeURIComponent(value)
    end

    def self.escape_params(params)
      params.map { |k, v| "#{k}=#{escape(v)}" }.join("&")
    end
  end
end
