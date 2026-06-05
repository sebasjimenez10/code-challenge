require "json"
require "artwork"

RSpec.describe Artwork do
  subject(:artwork) do
    described_class.new(
      name: "The Starry Night",
      extensions: ["1889"],
      link: "https://www.google.com/search?q=The+Starry+Night",
      image: "data:image/jpeg;base64,/9j/4AAQ"
    )
  end

  it "exposes its attributes" do
    expect(artwork.name).to eq("The Starry Night")
    expect(artwork.extensions).to eq(["1889"])
    expect(artwork.link).to eq("https://www.google.com/search?q=The+Starry+Night")
    expect(artwork.image).to eq("data:image/jpeg;base64,/9j/4AAQ")
  end

  describe "#to_h" do
    it "renders the four-key output hash in schema order" do
      expect(artwork.to_h).to eq(
        "name" => "The Starry Night",
        "extensions" => ["1889"],
        "link" => "https://www.google.com/search?q=The+Starry+Night",
        "image" => "data:image/jpeg;base64,/9j/4AAQ"
      )
    end

    it "omits the extensions key when there are no extensions" do
      dateless = described_class.new(
        name: "Sunflowers", extensions: [], link: "https://example.test", image: nil
      )
      expect(dateless.to_h).to eq(
        "name" => "Sunflowers",
        "link" => "https://example.test",
        "image" => nil
      )
      expect(dateless.to_h).not_to have_key("extensions")
    end
  end

  describe "#to_json" do
    it "serializes the output hash to JSON" do
      expect(JSON.parse(artwork.to_json)).to eq(artwork.to_h)
    end

    it "preserves schema key order" do
      expect(artwork.to_json).to start_with('{"name":"The Starry Night"')
    end
  end
end
