module X
  # The version of this library
  module Version
    module_function

    def major
      0
    end

    def minor
      2
    end

    def patch
      0
    end

    def pre
      nil
    end

    def to_h
      {
        major: major,
        minor: minor,
        patch: patch,
        pre: pre
      }
    end

    def to_a
      [major, minor, patch, pre].compact
    end

    def to_s
      to_a.join(".")
    end
  end
end
