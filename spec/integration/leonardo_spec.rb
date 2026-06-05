require "json"
require "search_result"

# Third content page (DESIGN.md Section 5). A different artist and item set, parsed by the
# same structural strategy with no code changes — including a dateless famous work
# (Vitruvian Man) that exercises the omitted-extensions path.
#
# As with picasso, there is no SerpApi example: leonardo-da-vinci-expected-array.json
# is a generated, spot-verified snapshot used for exact-match regression, with
# independent inspection-derived counts alongside.
RSpec.describe "Leonardo da Vinci paintings page (third layout)" do
  let(:files_dir) { File.expand_path("../../files", __dir__) }
  let(:result) { SearchResult.from_file(File.join(files_dir, "leonardo-da-vinci-paintings.html")) }
  let(:expected) { JSON.parse(File.read(File.join(files_dir, "leonardo-da-vinci-expected-array.json"))) }
  let(:artworks) { result.to_h["artworks"] }

  it "matches the leonardo snapshot exactly" do
    expect(result.to_h).to eq(expected)
  end

  it "extracts all 47 carousel paintings" do
    expect(artworks.size).to eq(47)
  end

  it "gives every artwork a non-empty name and an absolute link" do
    expect(artworks.map { |a| a["name"] }).to all(satisfy { |n| n.is_a?(String) && !n.empty? })
    expect(artworks.map { |a| a["link"] }).to all(start_with("https://www.google.com/search?"))
  end

  it "resolves images: 8 inline base64 + 39 thumbnail URLs, none missing" do
    images = artworks.map { |a| a["image"] }
    expect(images.count { |i| i.to_s.start_with?("data:image/jpeg;base64,") }).to eq(8)
    expect(images.count { |i| i.to_s.start_with?("https://encrypted-tbn") }).to eq(39)
    expect(images).to all(be_truthy)
  end

  it "extracts dates as extensions where present (34 of 47)" do
    expect(artworks.count { |a| a.key?("extensions") }).to eq(34)
  end

  it "spot-checks the first artwork" do
    first = artworks.first
    expect(first["name"]).to eq("Salvator Mundi")
    expect(first["extensions"]).to eq(["1500"])
    expect(first["image"]).to start_with("data:image/jpeg;base64,")
  end

  it "omits extensions for a dateless work (Vitruvian Man)" do
    vitruvian = artworks.find { |a| a["name"] == "Vitruvian Man" }
    expect(vitruvian).not_to be_nil
    expect(vitruvian).not_to have_key("extensions")
  end
end
