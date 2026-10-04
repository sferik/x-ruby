# frozen_string_literal: true

# Type checks the x meta-gem against the signatures that x-core, x-uploads, x-streams, and x-resources ship.
# Each of those gems type checks itself with its own Steepfile.
target :lib do
  signature "sig"
  signature "x-core/sig/x-core.rbs"
  signature "x-uploads/sig/x-uploads.rbs"
  signature "x-streams/sig/x-streams.rbs"
  signature "x-resources/sig/x-resources.rbs"
  check "lib"
  library "forwardable"
  library "json"
  library "monitor"
  library "net-http"
  library "openssl"
  library "securerandom"
  library "simple_oauth"
  library "time"
  library "tmpdir"
  library "uri"
  library "zlib"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end
