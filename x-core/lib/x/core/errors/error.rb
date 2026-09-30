# frozen_string_literal: true

module X
  # The base class of every error the X gems raise
  #
  # Rescuing it catches every way a request can fail: an HTTPError for a response that failed, a NetworkError for
  # a request that never got a response, and the errors the gems raise for what they will not send or cannot read.
  #
  #   X::Error
  #   ├── X::HTTPError                 a response the API refused, or one it sent that is not JSON, which the error holds
  #   │   ├── X::ClientError           4xx: the request was refused, and is refused again but for a 408 or 429
  #   │   │   ├── X::BadRequest                 400
  #   │   │   ├── X::Unauthorized               401
  #   │   │   ├── X::PaymentRequired            402
  #   │   │   ├── X::Forbidden                  403
  #   │   │   ├── X::NotFound                   404
  #   │   │   ├── X::MethodNotAllowed           405
  #   │   │   ├── X::NotAcceptable              406
  #   │   │   ├── X::RequestTimeout             408
  #   │   │   ├── X::Conflict                   409
  #   │   │   ├── X::Gone                       410
  #   │   │   ├── X::PayloadTooLarge            413
  #   │   │   ├── X::UnsupportedMediaType       415
  #   │   │   ├── X::UnprocessableEntity        422
  #   │   │   ├── X::TooManyRequests            429
  #   │   │   └── X::UnavailableForLegalReasons 451
  #   │   ├── X::ServerError           5xx: the API failed, and the same request may pass later
  #   │   │   ├── X::InternalServerError        500
  #   │   │   ├── X::BadGateway                 502
  #   │   │   ├── X::ServiceUnavailable         503
  #   │   │   └── X::GatewayTimeout             504
  #   │   └── X::InvalidResponse       2xx: a response that succeeded, whose body is not the JSON it claims
  #   ├── X::NetworkError              the request never reached the API, or its response never arrived
  #   ├── X::AuthorizationError        X refused to issue a token, or the user did not authorize the app
  #   ├── X::TokenReportFailed         save_tokens raised for the tokens of an exchange of a code or a refresh
  #   ├── X::TooManyRedirects          a response redirected more times than max_redirects allows
  #   ├── X::StreamError               a line of a stream held errors and no data
  #   ├── X::RulesRejected             the API left rules of the filtered stream unchanged, and no block took them
  #   ├── X::UnsupportedOperation      the API offers no way to do what was asked
  #   ├── X::UnsupportedMarshalFormat  Marshal or YAML read a state written in a format this release does not read
  #   ├── X::Objects::Error            the failures of the object layer, from x-objects
  #   │   ├── X::MissingResource               a resource that was asked for does not exist
  #   │   ├── X::UnreadableResponse            a response that succeeded says what the API does not document
  #   │   │   └── X::InvalidAttribute          a response holds a value that is not what the API documents it to be
  #   │   └── X::MissingClient                 a resource that holds no client was asked to make a request
  #   └── X::Uploader::Error           the failures of an upload, from x-uploader
  #       ├── X::InvalidMedia                  the media does not exist, cannot be read, is empty, or is too large
  #       │   └── X::InvalidMediaType          the media is of a type the API does not take
  #       ├── X::ChunkedUploadFailed           a chunk or the finalize of an initialized upload failed
  #       ├── X::AltTextFailed                 the media was uploaded, but its alt text could not be added
  #       ├── X::MediaProcessingCheckFailed    the media was uploaded, but a check of its processing failed
  #       ├── X::MediaProcessingFailed         X could not process the media that was uploaded
  #       ├── X::MediaProcessingTimeout        the media was still processing when the wait ran out
  #       └── X::MissingMediaData              a response of an upload describes no media
  #
  # @api public
  # @example Rescue every failure of a request
  #   begin
  #     client.get("users/me")
  #   rescue X::Error => e
  #     logger.error(e.message)
  #   end
  class Error < StandardError; end
end
