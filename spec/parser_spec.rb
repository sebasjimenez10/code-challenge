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

  # Newer captures (e.g. the Taylor Swift albums page) leave the img alt empty and
  # carry the title only in the first caption row instead of duplicating it in alt.
  describe "name falls back to the caption when the img alt is empty" do
    let(:html) do
      <<~HTML
        <html><body>
          <div class="iELo6">
            <a href="/search?q=Lover&amp;stick=LV">
              <img class="taFZJe" alt=""
                   data-src="https://encrypted-tbn0.gstatic.com/images?q=tbn:LOV"
                   src="data:image/gif;base64,PLACEHOLDER" />
              <div class="KHK6lb">
                <div class="pgNMRc">Lover</div>
                <div class="cxzHyb">2019</div>
              </div>
            </a>
          </div>
        </body></html>
      HTML
    end

    it "uses the first caption row as the name, keeping the date in extensions" do
      art = described_class.new(html).artworks.first
      expect(art.name).to eq("Lover")
      expect(art.extensions).to eq(["2019"])
    end
  end

  # Newer captures pre-render only the first cells; the rest arrive as escaped HTML
  # inside a <script> (a lazily-injected grid). The parser decodes and parses it.
  describe "items deferred into an escaped-HTML script grid" do
    # Single-quoted heredoc: backslash escapes stay literal, mirroring the raw page.
    let(:html) do
      <<~'HTML'
        <html><body>
          <div class="iELo6">
            <a href="/search?q=Lover&amp;stick=LV">
              <img alt="Lover"
                   data-src="https://encrypted-tbn0.gstatic.com/images?q=tbn:LOV"
                   src="data:image/gif;base64,PLACEHOLDER" />
              <div class="KHK6lb"><div class="pgNMRc">Lover</div><div class="cxzHyb">2019</div></div>
            </a>
          </div>
          <script>
            window.grid = [
              '\x3ca href="/search?q=Fearless\x26stick=FV"\x3e\x3cwp-grid-tile\x3e\x3cimg alt="" data-src="https://encrypted-tbn0.gstatic.com/images?q=tbn:FV"\x3e\x3cdiv class="JjtOHd"\x3eFearless (Taylor\u2019s Version)\x3c/div\x3e\x3cdiv class="cHaqb"\x3e2021, EP\x3c/div\x3e\x3c/wp-grid-tile\x3e\x3c/a\x3e',
            ];
          </script>
        </body></html>
      HTML
    end

    let(:artworks) { described_class.new(html).artworks }

    it "extracts both the DOM cell and the script-only cell" do
      # The script title's ’ escape is decoded to a curly apostrophe.
      expect(artworks.map(&:name)).to eq(["Lover", "Fearless (Taylor’s Version)"])
    end

    it "decodes the deferred item's fields" do
      grid_item = artworks.last
      expect(grid_item.extensions).to eq(["2021, EP"])
      expect(grid_item.link).to eq("https://www.google.com/search?q=Fearless&stick=FV")
      expect(grid_item.image).to eq("https://encrypted-tbn0.gstatic.com/images?q=tbn:FV")
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
