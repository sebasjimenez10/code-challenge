# frozen_string_literal: true

require "json"

# Represent an artwork object from the artwork carousel.
class Artwork
  attr_reader :name, :extensions, :link, :image

  def initialize(name:, extensions:, link:, image:)
    @name = name
    @extensions = extensions
    @link = link
    @image = image
  end

  def to_h
    hash = {
      "name" => name,
      "link" => link,
      "image" => image
    }

    hash["extensions"] = extensions unless extensions.nil? || extensions.empty?
    hash
  end

  def to_json(*args)
    to_h.to_json(*args)
  end
end
