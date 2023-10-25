module X
  # Base Authenticator class
  class Authenticator
    AUTHENTICATION_HEADER = "Authorization".freeze

    def header(_request)
      {AUTHENTICATION_HEADER => ""}
    end
  end
end
