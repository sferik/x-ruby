module X
  # Base Authenticator class
  class Authenticator
    def header(_request)
      {"Authorization" => ""}
    end
  end
end
