# frozen_string_literal: true

require_relative "resource"

module X
  # A folder the authenticated user keeps bookmarks in
  #
  # The API offers no lookup of a folder, so a folder is read from the bookmark folders of the user it belongs to,
  # which X::User#bookmark_folders pages through, and the class answers no finder. from_id builds one from its
  # identifier, which X::User#bookmarks takes as the folder to read the posts of, but hydrate and refresh raise
  # UnsupportedOperation for one that is not hydrated, since there is nothing to look it up with.
  #
  # @api public
  class BookmarkFolder < Resource
    # @!attribute [r] name
    #   The name of the folder
    #   @api public
    #   @return [String, nil] the name
    #   @example Get the name
    #     folder.name # => "Ruby"
    attribute :name
  end
end
