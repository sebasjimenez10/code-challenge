require "json"
require "search_result"

# End-to-end: the real saved page must reproduce files/van-gogh-expected-array.json
# exactly (DESIGN.md Section 5). This is the authoritative, SerpApi-provided example.
RSpec.describe "Van Gogh paintings page" do
  let(:files_dir) { File.expand_path("../../files", __dir__) }
  let(:result) { SearchResult.from_file(File.join(files_dir, "van-gogh-paintings.html")) }
  let(:expected) { JSON.parse(File.read(File.join(files_dir, "van-gogh-expected-array.json"))) }
  let(:artworks) { result.to_h["artworks"] }

  it "extracts all 47 carousel paintings" do
    expect(artworks.size).to eq(47)
  end

  it "matches the expected array exactly" do
    expect(result.to_h).to eq(expected)
  end

  it "matches every artwork field-by-field" do
    artworks.zip(expected["artworks"]).each_with_index do |(actual, want), i|
      expect(actual).to eq(want), "artwork ##{i} (#{want["name"].inspect}) mismatch"
    end
  end

  it "has the expected image coverage: 8 inline base64 + 39 thumbnail URLs" do
    images = artworks.map { |a| a["image"] }
    expect(images.count { |i| i.start_with?("data:image/jpeg;base64,") }).to eq(8)
    expect(images.count { |i| i.start_with?("https://encrypted-tbn") }).to eq(39)
    expect(images).to all(be_truthy)
  end

  it "absolutizes every Google link" do
    expect(artworks.map { |a| a["link"] }).to all(start_with("https://www.google.com/search?"))
  end
end
