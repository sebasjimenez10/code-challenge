require "json"
require "search_result"

# Deferred-grid regression (DESIGN.md Section 2a). The Dream Theater albums page is a
# newer capture that pre-renders only the first 12 cells into the DOM and ships the
# remaining 36 as escaped HTML inside a <script>. A DOM-only parser finds just 12;
# decoding the script grid and merging (deduped by q=) recovers all 48.
#
# There is no SerpApi-provided example for this page, so these are independent,
# inspection-derived counts rather than a golden-file match.
RSpec.describe "Dream Theater albums page (deferred script grid)" do
  let(:files_dir) { File.expand_path("../../files", __dir__) }
  let(:result) { SearchResult.from_file(File.join(files_dir, "dream-theater-albums.html")) }
  let(:artworks) { result.to_h["artworks"] }

  it "recovers all 51 albums" do
    expect(artworks.size).to eq(51)
  end

  it "gives every album a non-empty name and an absolute link" do
    expect(artworks.map { |a| a["name"] }).to all(satisfy { |n| n.is_a?(String) && !n.empty? })
    expect(artworks.map { |a| a["link"] }).to all(start_with("https://www.google.com/search?"))
  end

  it "resolves an image for every album (12 inline base64 + 39 URLs, none missing)" do
    images = artworks.map { |a| a["image"] }
    expect(images).to all(be_truthy)
    expect(images.count { |i| i.start_with?("data:image/jpeg;base64,") }).to eq(12)
    expect(images.count { |i| !i.start_with?("data:image/jpeg;base64,") }).to eq(39)
  end

  it "spot-checks a DOM-rendered album (the first cell)" do
    first = artworks.first
    expect(first["name"]).to eq("Images and Words")
    expect(first["extensions"]).to eq(["1992"])
    expect(first["image"]).to start_with("data:image/jpeg;base64,")
  end

  it "spot-checks a script-only album (recovered from the deferred grid)" do
    fearless = artworks.find { |a| a["name"] == "Systematic Chaos" }
    expect(fearless).not_to be_nil
    expect(fearless["image"]).to start_with("https://encrypted-tbn")
    expect(fearless["link"]).to start_with("https://www.google.com/search?")
  end
end
