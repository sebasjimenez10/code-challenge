# frozen_string_literal: true

require "nokogiri"
require_relative "artwork"
require_relative "image_resolver"

# Parses a saved Google results page and extracts the paintings carousel as a
# collection of Artwork value objects (see DESIGN.md Sections 3-4).
#
# The selectors are deliberately *structural* rather than class-based: Google
# rotates its obfuscated class names between captures.
#
# Carousel cells live in the live DOM, except on newer captures, which pre-render
# only the first cells and ship the rest as escaped HTML inside a <script> (a
# lazily-injected grid). We decode those scripts back into parseable documents and
# run the *same* extraction rule over every document.
class Parser
  GOOGLE_HOST = "https://www.google.com"

  # A knowledge-graph carousel link that wraps a thumbnail image.
  CAROUSEL_ANCHOR_SELECTOR = "a[href*='stick=']"

  def initialize(html)
    @document = Nokogiri::HTML(html)
    @image_resolver = ImageResolver.new(@document)
  end

  def artworks
    sources.flat_map { |doc| carousel_anchors(doc) }.map { |anchor| build_artwork(anchor) }
  end

  private

  # The live document, plus any deferred grid a newer capture hid as escaped HTML
  # inside a <script>, decoded back into a parseable document.
  def sources
    [@document] + @document.css("script").filter_map { |script| decoded_grid(script.content) }
  end

  def decoded_grid(body)
    Nokogiri::HTML(unescape_js(body)) if body.include?("stick=")
  end

  def carousel_anchors(doc)
    doc.css(CAROUSEL_ANCHOR_SELECTOR).select { |anchor| anchor.at_css("img") }
  end

  def build_artwork(anchor)
    img = anchor.at_css("img")
    captions = caption_texts(anchor)

    Artwork.new(
      name: name_for(img, captions),
      extensions: captions.drop(1), # caption rows after the title (e.g. the date)
      link: link_for(anchor),
      image: @image_resolver.resolve(img)
    )
  end

  # The title is the img alt on older captures; newer captures leave the alt
  # empty and carry the title only in the first caption row. Prefer the alt.
  def name_for(img, captions)
    alt = normalize(img["alt"])
    alt.empty? ? captions.first.to_s : alt
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

  # A script serializes the grid HTML as a JS string: `<` becomes `\x3c`, non-ASCII
  # becomes `\uXXXX`, and quotes/slashes are backslash-escaped. Decode them all back.
  def unescape_js(str)
    str
      .gsub(/\\x(\h{2})|\\u(\h{4})/) { (Regexp.last_match(1) || Regexp.last_match(2)).hex.chr(Encoding::UTF_8) }
      .gsub(%r{\\(['"/\\])}, '\1')
  end
end
