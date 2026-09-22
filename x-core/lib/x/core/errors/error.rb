# frozen_string_literal: true

module X
  # The base class of every error the X gems raise
  #
  # Rescuing it catches every way a request can fail: an HTTPError for a response the API refused, a NetworkError for
  # a request that never got a response, and the errors the gems raise for what they will not send or cannot read.
  #
  #   X::Error
  #   ├── X::HTTPError                 a response the API refused, which the error holds
  #   │   ├── X::ClientError           4xx: the request was refused, and the same request is refused again
  #   │   │   ├── X::BadRequest                 400
  #   │   │   ├── X::Unauthorized               401
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
  #   │   └── X::ServerError           5xx: the API failed, and the same request may pass later
  #   │       ├── X::InternalServerError        500
  #   │       ├── X::BadGateway                 502
  #   │       ├── X::ServiceUnavailable         503
  #   │       └── X::GatewayTimeout             504
  #   ├── X::NetworkError              the request never reached the API, or its response never arrived
  #   ├── X::InvalidResponse           a response that succeeded, whose body is not the JSON it claims
  #   ├── X::AuthorizationError        X refused to issue a token, or the user did not authorize the app
  #   ├── X::TooManyRedirects          a response redirected more times than max_redirects allows
  #   ├── X::UnsupportedOperation      the API offers no way to do what was asked
  #   ├── X::Objects::Error            the failures of the object layer, from x-objects
  #   │   └── X::MissingResource               a resource that was asked for does not exist
  #   └── X::Uploader::Error           the failures of an upload, from x-uploader
  #       ├── X::InvalidMediaType              the media is of a type the API does not take
  #       ├── X::MediaProcessingFailed         X could not process the media that was uploaded
  #       ├── X::MediaProcessingTimeout        the media was still processing when the wait ran out
  #       └── X::MissingData                   a response of an upload describes no media
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
