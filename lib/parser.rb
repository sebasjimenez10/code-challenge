# frozen_string_literal: true

require "nokogiri"
require_relative "artwork"
require_relative "image_resolver"

# Parses a saved Google results page and extracts the paintings carousel as a
# collection of Artwork value objects (see DESIGN.md Sections 3-4).
#
# The selectors are deliberately *structural* rather than class-based: Google
# rotates its obfuscated class names between captures.
class Parser
  GOOGLE_HOST = "https://www.google.com"

  # A knowledge-graph carousel link that wraps a thumbnail image.
  CAROUSEL_ANCHOR_SELECTOR = "a[href*='stick=']"

  def initialize(html)
    @document = Nokogiri::HTML(html)
    @image_resolver = ImageResolver.new(@document)
  end

  def artworks
    carousel_anchors.map { |anchor| build_artwork(anchor) }
  end

  private

  def carousel_anchors
    @document.css(CAROUSEL_ANCHOR_SELECTOR).select { |a| a.at_css("img") }
  end

  def build_artwork(anchor)
    img = anchor.at_css("img")

    Artwork.new(
      name: normalize(img["alt"]), # the img alt is the painting title on every capture
      extensions: caption_texts(anchor).drop(1), # caption rows after the title (e.g. the date)
      link: link_for(anchor),
      image: @image_resolver.resolve(img)
    )
  end

  # The caption is a stack of leaf <div> text rows (title first, then metadata
  # such as the date). Leaf = a <div> with no nested <div>.
  def caption_texts(anchor)
    anchor.css("div")
      .reject { |div| div.at_css("div") }
      .map { |div| normalize(div.text) }
      .reject(&:empty?)
  end

  # Carousel hrefs are always Google-relative (`/search?...`); Nokogiri has already
  # decoded the HTML entities.
  def link_for(anchor)
    "#{GOOGLE_HOST}#{anchor["href"]}"
  end

  def normalize(text)
    text.to_s.gsub(/\s+/, " ").strip
  end
end
