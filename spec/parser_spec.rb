require "parser"

RSpec.describe Parser do
  # Mirrors the real carousel markup (DESIGN.md Section 2): each item is a div.iELo6
  # wrapping an <a> with an img.taFZJe, a div.pgNMRc (name) and div.cxzHyb (date).
  #   - item 1: inline base64 (img has id, matching _setImagesSrc script)
  #   - item 2: lazy URL (img has data-src), and no date div
  let(:html) do
    <<~HTML
      <html><body>
        <g-scrolling-carousel>
          <div class="iELo6">
            <a href="/search?q=The+Starry+Night&amp;stick=ABC">
              <img class="taFZJe" alt="The Starry Night" id="img-1"
                   src="data:image/gif;base64,PLACEHOLDER" />
              <div class="KHK6lb">
                <div class="pgNMRc">The
                  Starry
                  Night</div>
                <div class="cxzHyb">1889</div>
              </div>
            </a>
          </div>
          <div class="iELo6">
            <a href="/search?q=Irises&amp;stick=DEF">
              <img class="taFZJe" alt="Irises" id="img-2"
                   data-src="https://encrypted-tbn0.gstatic.com/images?q=tbn:XYZ"
                   src="data:image/gif;base64,PLACEHOLDER" />
              <div class="KHK6lb">
                <div class="pgNMRc">Irises</div>
              </div>
            </a>
          </div>
        </g-scrolling-carousel>

        <script>
          var s = "data:image/jpeg;base64,/9j/STARRY";
          var ii = ["img-1"];
          _setImagesSrc(ii, s, r);
        </script>
      </body></html>
    HTML
  end

  subject(:parser) { described_class.new(html) }
  let(:artworks) { parser.artworks }

  it "returns one Artwork per carousel item" do
    expect(artworks.size).to eq(2)
    expect(artworks).to all(be_a(Artwork))
  end

  describe "the first artwork (base64 image)" do
    subject(:art) { artworks.first }

    it "normalizes the name's internal whitespace" do
      expect(art.name).to eq("The Starry Night")
    end

    it "wraps the date in an extensions array" do
      expect(art.extensions).to eq(["1889"])
    end

    it "absolutizes the Google link and decodes entities" do
      expect(art.link).to eq("https://www.google.com/search?q=The+Starry+Night&stick=ABC")
    end

    it "resolves the inline base64 image" do
      expect(art.image).to eq("data:image/jpeg;base64,/9j/STARRY")
    end
  end

  describe "the second artwork (url image, no date)" do
    subject(:art) { artworks.last }

    it "has an empty extensions array when no date div is present" do
      expect(art.extensions).to eq([])
    end

    it "resolves the data-src thumbnail URL" do
      expect(art.image).to eq("https://encrypted-tbn0.gstatic.com/images?q=tbn:XYZ")
    end
  end

  # Google rotates the obfuscated class names between captures, so the parser must
  # rely on structure (a stick anchor wrapping an img + a title/date caption),
  # not on specific class names.
  describe "class independence" do
    let(:html) do
      <<~HTML
        <html><body>
          <div class="ZZZrotated">
            <a href="/search?q=Guernica&amp;stick=GG">
              <img class="qWeRtY" alt="Guernica"
                   data-src="https://encrypted-tbn0.gstatic.com/images?q=tbn:GUE"
                   src="data:image/gif;base64,PLACEHOLDER" />
              <div class="aBcDeF">
                <div class="t1t1t1">Guernica</div>
                <div class="d8d8d8">1937</div>
              </div>
            </a>
          </div>
        </body></html>
      HTML
    end

    it "parses an item whose class names are unknown" do
      art = described_class.new(html).artworks.first
      expect(art.name).to eq("Guernica")
      expect(art.extensions).to eq(["1937"])
      expect(art.link).to eq("https://www.google.com/search?q=Guernica&stick=GG")
      expect(art.image).to eq("https://encrypted-tbn0.gstatic.com/images?q=tbn:GUE")
    end
  end
end
