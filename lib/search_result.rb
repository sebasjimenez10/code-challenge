# frozen_string_literal: true

require "json"
require_relative "parser"

# Public entry point. Wraps a results page and renders the SerpApi-shaped
# `{ "artworks" => [...] }` output (see DESIGN.md Section 3).
class SearchResult
  def self.from_file(path)
    new(File.read(path))
  end

  def initialize(html)
    @parser = Parser.new(html)
  end

  def artworks
    @artworks ||= @parser.artworks
  end

  def to_h
    {"artworks" => artworks.map(&:to_h)}
  end

  def to_json(*args)
    to_h.to_json(*args)
  end
end
