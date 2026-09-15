# Type checks the x meta-gem against the signatures that x-core and x-objects ship.
# Each of those gems type checks itself with its own Steepfile.
target :lib do
  signature "sig"
  signature "x-core/sig/x-core.rbs"
  signature "x-uploader/sig/x-uploader.rbs"
  signature "x-objects/sig/x-objects.rbs"
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
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end
