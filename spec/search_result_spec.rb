require "json"
require "search_result"

RSpec.describe SearchResult do
  let(:html) do
    <<~HTML
      <html><body>
        <div class="iELo6">
          <a href="/search?q=Irises&amp;stick=DEF">
            <img class="taFZJe" alt="Irises" id="img-1"
                 data-src="https://encrypted-tbn0.gstatic.com/images?q=tbn:XYZ"
                 src="data:image/gif;base64,PLACEHOLDER" />
            <div class="KHK6lb">
              <div class="pgNMRc">Irises</div>
              <div class="cxzHyb">1889</div>
            </div>
          </a>
        </div>
      </body></html>
    HTML
  end

  subject(:result) { described_class.new(html) }

  it "exposes the parsed artworks" do
    expect(result.artworks.size).to eq(1)
    expect(result.artworks.first).to be_a(Artwork)
  end

  describe "#to_h" do
    it "wraps the artworks under the 'artworks' key" do
      expect(result.to_h).to eq(
        "artworks" => [
          {
            "name" => "Irises",
            "extensions" => ["1889"],
            "link" => "https://www.google.com/search?q=Irises&stick=DEF",
            "image" => "https://encrypted-tbn0.gstatic.com/images?q=tbn:XYZ"
          }
        ]
      )
    end
  end

  describe "#to_json" do
    it "serializes the full result to JSON" do
      expect(JSON.parse(result.to_json)).to eq(result.to_h)
    end
  end
end
