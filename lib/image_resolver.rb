# frozen_string_literal: true

# Resolves a carousel <img> to its image source.
#
# Google delivers carousel images two ways (see DESIGN.md Section 2):
#   1. Inline base64 injected by `_setImagesSrc(ii, s, r)` scripts, keyed by img id.
#   2. A lazy-loaded `data-src` thumbnail URL.
# Anything else resolves to nil.
class ImageResolver
  # Captures the `s` (base64) and `ii` (id list) of one _setImagesSrc block.
  # `s` precedes `ii`; whitespace/newlines between tokens are tolerated.
  # Groups:
  # 1. ([^"]*) — the base64 payload between the quotes in var s = "…" → bound to base64
  # 2. ([^\]]*) — the raw contents between the brackets in var ii = […] → bound to id_list
  SCRIPT_BLOCK = /var\s+s\s*=\s*"([^"]*)"\s*;\s*var\s+ii\s*=\s*\[([^\]]*)\]/m
  QUOTED = /"([^"]*)"/

  def initialize(document)
    @base64_by_id = build_base64_map(document)
  end

  def resolve(img)
    id = img["id"]
    return @base64_by_id[id] if id && @base64_by_id.key?(id)

    data_src = img["data-src"]
    return data_src if data_src && !data_src.empty?

    nil
  end

  private

  def build_base64_map(document)
    map = {}
    document.css("script").each do |script|
      script.content.scan(SCRIPT_BLOCK) do |base64, id_list|
        value = unescape_js(base64)
        id_list.scan(QUOTED).flatten.each { |id| map[id] = value }
      end
    end

    map
  end

  # The base64 lives in a JS string literal where the `=` padding is hex-escaped
  # as `\x3d` (the only escape seen across captures). Decodes any `\xHH` back to its character.
  def unescape_js(str)
    str.gsub(/\\x(\h{2})/) { [Regexp.last_match(1).hex].pack("U") }
  end
end
