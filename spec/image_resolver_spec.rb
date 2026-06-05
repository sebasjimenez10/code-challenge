require "nokogiri"
require "image_resolver"

RSpec.describe ImageResolver do
  # A minimal document exercising all three resolution paths:
  #   - img#base64-img  -> base64 injected by a _setImagesSrc script
  #   - img#url-img     -> lazy-loaded data-src URL
  #   - img#bare-img    -> neither, resolves to nil
  let(:html) do
    <<~HTML
      <html><body>
        <img id="base64-img" src="data:image/gif;base64,PLACEHOLDER" />
        <img id="url-img" data-src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ABC" src="data:image/gif;base64,PLACEHOLDER" />
        <img id="bare-img" src="data:image/gif;base64,PLACEHOLDER" />

        <script>
          (function () {
            var s = "data:image/jpeg;base64,/9j/4AAQreal";
            var ii = ["base64-img"];
            var r = "";
            _setImagesSrc(ii, s, r);
          })();
        </script>
      </body></html>
    HTML
  end

  let(:document) { Nokogiri::HTML(html) }
  subject(:resolver) { described_class.new(document) }

  def img(id)
    document.at_css("img##{id}")
  end

  describe "#resolve" do
    it "returns the inline base64 image when the img id is in a _setImagesSrc block" do
      expect(resolver.resolve(img("base64-img"))).to eq("data:image/jpeg;base64,/9j/4AAQreal")
    end

    it "returns the data-src URL when there is no inline base64" do
      expect(resolver.resolve(img("url-img"))).to eq("https://encrypted-tbn0.gstatic.com/images?q=tbn:ABC")
    end

    it "returns nil when neither base64 nor data-src is present" do
      expect(resolver.resolve(img("bare-img"))).to be_nil
    end
  end

  # In practice each _setImagesSrc block carries a single id (the real pages emit
  # many such blocks, one per inline image); the map must accumulate across all of them.
  it "accumulates ids across multiple _setImagesSrc blocks, each to its own base64" do
    multi = Nokogiri::HTML(<<~HTML)
      <script>
        var s = "data:image/jpeg;base64,FIRST";
        var ii = ["a"];
        _setImagesSrc(ii, s, r);
      </script>
      <script>
        var s = "data:image/jpeg;base64,SECOND";
        var ii = ["b"];
        _setImagesSrc(ii, s, r);
      </script>
      <img id="a" /><img id="b" />
    HTML
    resolver = described_class.new(multi)
    expect(resolver.resolve(multi.at_css("img#a"))).to eq("data:image/jpeg;base64,FIRST")
    expect(resolver.resolve(multi.at_css("img#b"))).to eq("data:image/jpeg;base64,SECOND")
  end
end
