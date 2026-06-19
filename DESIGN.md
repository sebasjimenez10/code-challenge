# Solution Design

Extract a Google knowledge-graph paintings carousel from a saved results page into a JSON array. The HTML file is parsed directly — **no additional HTTP requests**.

## Approach summary

The carousel is parsed **structurally, not by CSS class**, because Google rotates its obfuscated class names (verified: van-gogh's classes are 100% absent from the newer Picasso page, where a class-based parser returns **0** items). Three small objects do the work:

- **`Parser`** — finds each item as a `stick=` search link that wraps an `<img>`, then reads `name` (the img `alt`, falling back to the first caption row when `alt` is empty), `extensions` (caption rows after the title), and `link` (the absolutized `href`). It looks in **two places**: the live DOM and the escaped-HTML grid that newer captures defer into a `<script>` (Section 2a).
- **`ImageResolver`** — supplies the image without any network call: inline base64 (injected by `_setImagesSrc` scripts, keyed by img `id`) or the lazy `data-src` thumbnail URL.
- **`Artwork` / `SearchResult`** — render the `{ "artworks": [...] }` output.

Validated against four real pages: van-gogh (47 items, exact match to the SerpApi-provided example), Picasso (45 items), Leonardo da Vinci (47 items), and a Taylor Swift albums page (48 items — 12 rendered in the DOM plus 36 deferred into a script grid). The middle two via generated, spot-verified snapshots plus independent counts.

## 1. Output schema

```json
{
  "artworks": [
    {
      "name": "The Starry Night",
      "link": "https://www.google.com/search?...",
      "image": "data:image/jpeg;base64,...", // or an https URL, or null
      "extensions": ["1889"] // optional — omitted when there is no date
    }
  ]
}
```

- `name` — String. The painting title.
- `link` — String. Absolute Google search URL.
- `image` — String or null. Inline base64 data URI, a `gstatic` thumbnail URL, or `null` if neither is present in the file.
- `extensions` — Array of String. Models SerpApi's field; on this page it holds at most the date (e.g. `"1889"`). **The key is omitted entirely when no date is present** (4 of 47 items), matching `van-gogh-expected-array.json`.

## 2. How an item is recognized

Each painting is one carousel cell — a single `<a>` anchor, annotated below. The parser matches on its **structure**, never on class names, which change over time (Section 4):

```html
<a href="/search?...&q=The+Starry+Night&stick=H4sI...">  <!-- (1) a "stick=" search link... -->
  <img alt="The Starry Night"                            <!-- (2) ...wrapping an <img>; alt = name* -->
       id="_L_FkZ...63"                                  <!--     id       -> inline base64 (first 8) -->
       data-src="https://encrypted-tbn0.gstatic..."      <!--     data-src -> thumbnail URL (the rest) -->
       src="data:image/gif;base64,...1x1 placeholder..."/>
  <div>                                                  <!-- (3) caption = stack of leaf <div> rows -->
    <div>The Starry Night</div>                          <!--     row 1 = title    -> name (fallback) -->
    <div>1889</div>                                      <!--     row 2 = metadata -> extensions -->
  </div>
</a>
```

\* On the three paintings pages the `alt` carries the title (and the caption duplicates it in row 1). On the newer Taylor Swift capture the `alt` is empty and the title lives **only** in caption row 1 — so `name` reads the `alt` when present and otherwise falls back to the first caption row.

These signals — a `stick=` link wrapping an `<img>`, the caption leaf rows, and the img `id`/`data-src` — appear on every capture. Only the class names differ between pages, which is exactly why we don't match on them:

| Structural role | van-gogh class | picasso class | leonardo class |
| --------------- | -------------- | ------------- | -------------- |
| item wrapper    | `iELo6`        | `TILZre`      | `TILZre`       |
| thumbnail img   | `taFZJe`       | `pHjwVc`      | `pHjwVc`       |
| caption box     | `KHK6lb`       | `Y5eSNd`      | `Y5eSNd`       |
| title row       | `pgNMRc`       | `yfEcJe`      | `yfEcJe`       |
| date row        | `cxzHyb`       | `DWyOHb`      | `DWyOHb`       |

Picasso and Leonardo share one capture generation (identical classes); van-gogh is an older one. The structural parser handles all three unchanged.

### Field sources

| Field        | Source                                          | Handling                                                                             |
| ------------ | ----------------------------------------------- | ------------------------------------------------------------------------------------ |
| `name`       | `img@alt`, else caption row 1                   | Collapse internal whitespace/newlines; fall back to the first caption row when `alt` is empty (newer captures). |
| `extensions` | caption leaf divs after the title (e.g. `1937`) | Array of the remaining rows; `[]` when absent or blank (key omitted at render time). |
| `link`       | `a@href`                                        | Relative `/search?...` → prepend `https://www.google.com`; decode HTML entities.     |
| `image`      | see Section 3 (ImageResolver)                   | The img's own `src` is a throwaway 1×1 gif — always ignored.                         |

### Image delivery: two mechanisms

1. **Inline base64.** The `<img>` has an `id` and no `data-src`. The real JPEG is injected by a script block elsewhere in the document:

```js
(function () {
  var s = "data:image/jpeg;base64,/9j/4AAQ...";
  var ii = ["_L_FkZ4qlAtyDwbkP49Pj0QU_63"];
  var r = "";
  _setImagesSrc(ii, s, r);
})();
```

Each `_setImagesSrc` block pairs one base64 string (`s`) with a single image id (the sole `ii` entry); the resolver maps that id to the base64. The base64 lives inside a JS string literal where the `=` padding is hex-escaped as `\x3d` (the only escape seen across captures); it must be unescaped to match the expected output.

2. **Lazy-loaded URL.** The `<img>` carries `data-src="https://encrypted-tbn{0..3}.gstatic.com/images?q=tbn:..."`. We record the URL string as-is (no fetch).

Counts confirm the model against `files/van-gogh-expected-array.json`: 47 carousel items = 8 base64 + 39 `gstatic` URLs = 47 artworks.

## 2a. Two render locations (deferred grid)

The three paintings pages pre-render **every** carousel cell into the DOM. The newer Taylor Swift capture does not: it pre-renders only the first 12 cells and ships the remaining 36 as **escaped HTML inside a `<script>`** — a "show all albums" grid that Google's JS injects on demand. Nokogiri treats that script body as inert text, so a DOM-only parser sees just 12 of 48 items.

The fix keeps the parser purely structural and adds no special-casing. Each `<script>` whose body contains a serialized carousel link (`stick=`) is decoded — the JS-string escapes (`\xHH`, `\uHHHH`, and `\'`/`\"`/`\/`) are turned back into real HTML and re-parsed into its own document. The extractor then runs the **same** `stick=`-anchor-wrapping-`img` rule over every document (the live one plus any decoded grids) and concatenates the results. No dedup is needed: across all fixtures the DOM and the deferred grid are disjoint (the grid holds only the cells the DOM omitted), so a single uniform pass yields each item exactly once.

```html
<!-- inside a <script>, as a JS string literal: -->
\x3ca href="/search?...q=Fearless+(Taylor’s+Version)\x26stick=..."\x3e
  \x3cwp-grid-tile\x3e
    \x3cimg alt="" data-src="https://encrypted-tbn0.gstatic..."\x3e
    \x3cdiv\x3eFearless (Taylor’s Version)\x3c/div\x3e   <!-- title  -> name (alt is empty here) -->
    \x3cdiv\x3e2021, EP\x3c/div\x3e                          <!-- meta   -> extensions -->
  \x3c/wp-grid-tile\x3e
\x3c/a\x3e
```

The three paintings pages carry no such script anchors, so they are unaffected (47 / 45 / 47 unchanged); the Taylor Swift page goes from 12 → 48.

## 3. Entities

1. **`ImageResolver`** — Pre-scans the document's `<script>` text for `_setImagesSrc(...)` blocks and builds an `id → base64` map. Resolves an `<img>` to its image: base64 from the map (by `id`), else `data-src`, else `nil`.
2. **`Parser`** — Owns the Nokogiri document. Locates carousel items and, for each, extracts `name`, `extensions`, `link`, delegating the image to `ImageResolver`. Returns a collection of `Artwork`.
3. **`Artwork`** — Plain value object (`name`, `extensions`, `link`, `image`) that knows how to render itself to the output hash / JSON.
4. **`SearchResult`** — Thin facade and entry point: `SearchResult.from_file(path)` (or `.new(html)`) exposes `artworks` and renders `to_h` / `to_json` as `{ "artworks" => [...] }`.

> The classes are top-level for simplicity. In a larger codebase they'd be wrapped in a module (e.g. `ArtworkCarousel::Parser`) to avoid polluting the global namespace; it felt like overkill for four small files here.

## 4. Parsing flow

1. Read the HTML file; build a Nokogiri document.
2. `ImageResolver` builds the `id → base64` map from `_setImagesSrc` scripts.
3. Select carousel items structurally: `a[href*='stick=']` anchors that wrap an `<img>`, applied uniformly across the live DOM **and** any decoded script grid (Section 2a), concatenating the results. On the three paintings fixtures this isolates the carousel exactly (47 / 45 / 47) — the other `stick=` links are knowledge-graph/related-search links that don't wrap an image; on the Taylor Swift page it yields 48 (12 DOM + 36 script, disjoint).
4. Build an `Artwork` per anchor (fields per Section 2), resolving its image via `ImageResolver`.
5. Serialize to `{ "artworks" => [...] }`.

### Robustness for other layouts

The four structural signals are stable across captures; the class names are not (Section 2) — which is the whole reason we match on structure, and why the parser handles all three pages unchanged (47/47, 45/45, 47/47). The `[data-attrid$=":works"]` container also survives every capture, so it could serve as an optional sanity guard — but it is paintings-specific, and the structural rule alone already isolates the carousel exactly (47/45/47), so we didn't add it. The selector logic is isolated in `Parser` for per-layout tweaks.

## 5. Test plan (RSpec)

- **Schema/shape:** every artwork has the four keys; `extensions` is always an array.
- **Golden file:** parsing `files/van-gogh-paintings.html` equals `files/van-gogh-expected-array.json` (count = 47, and field-by-field equality).
- **Image coverage:** every page is exactly 8 base64 images plus the rest as `gstatic` URLs, with no `nil` — van-gogh 8 + 39 (47), picasso 8 + 37 (45), leonardo 8 + 39 (47).
- **Link normalization:** links are absolute `https://www.google.com/...`.
- **Second layout (`pablo-picasso-paintings.html`):** a more recent capture with rotated class names. No SerpApi example, so we use a generated, spot-verified snapshot (`pablo-picasso-expected-array.json`) for exact-match regression, plus independent inspection-derived counts (45 items, all named with absolute links, 39 dated) and a _Guernica_ spot-check.
- **Third page (`leonardo-da-vinci-paintings.html`):** a different artist/item set, parsed with no code changes. Snapshot `leonardo-da-vinci-expected-array.json` for exact-match regression, plus counts (47 items, 34 dated) and a _Salvator Mundi_ spot-check; _Vitruvian Man_ exercises the omitted-extensions (dateless) path.
- **Deferred script grid (`taylor-swift-albums.html`):** a newer capture that pre-renders only 12 of 48 albums into the DOM and defers the other 36 into an escaped-HTML `<script>`. The integration spec asserts all 48 are recovered, every one has a name/absolute link/non-nil image (12 base64 + 36 URLs), and spot-checks both a DOM-rendered album (_The Life of a Showgirl_) and a script-only one (_Fearless (Taylor's Version)_). Unit specs cover the mechanism in isolation: the empty-`alt` → caption name fallback and decoding an escaped grid item (incl. a `’` apostrophe).
- **Class independence:** a fixture with arbitrary/unknown class names still parses.

### Test coverage

SimpleCov (started in `spec/spec_helper.rb`, report written to `coverage/`):

- **Line coverage: 100.0%** (84 / 84)
- **Branch coverage: 100.0%** (10 / 10)

Coverage is kept at 100% by evidence, not speculation. An earlier pass removed conditionals that no capture exercised — including an empty-`alt` name fallback and a `\u`/`\<char>` escape fallback (the three paintings pages only use `\x`). The Taylor Swift page then provided that evidence: its grid tiles have empty `alt`s (re-justifying the caption fallback), and its deferred script grid uses `’` (curly apostrophe) and `\'` escapes (re-justifying the richer unescaper). Both were added back **with** fixtures that exercise them. The same principle removed a DOM/script dedup step: no fixture has an item in both places (the deferred grid holds only the cells the DOM omitted), so deduping was untriggered code — dropped, leaving a single uniform extraction pass.

## 6. Tech choices

**Ruby + RSpec + Nokogiri**, per the README's suggestion. Pure offline parsing — no network at runtime.

### Resources

- [README.md](./README.md) — challenge instructions
- `files/van-gogh-paintings.html` → input · `van-gogh-expected-array.json` → example (SerpApi-provided)
- `files/pablo-picasso-paintings.html` → input · `pablo-picasso-expected-array.json` → snapshot (generated, spot-verified)
- `files/leonardo-da-vinci-paintings.html` → input · `leonardo-da-vinci-expected-array.json` → snapshot (generated, spot-verified)
- `files/taylor-swift-albums.html` → input (deferred script grid; counts-only, no snapshot)

## 7. Versions

Developed and tested against:

| Tool      | Version | Notes                                  |
| --------- | ------- | -------------------------------------- |
| Ruby      | 4.0.0   | language runtime                       |
| Bundler   | 4.0.6   | dependency management (`BUNDLED WITH`) |
| Nokogiri  | 1.19.3  | HTML parsing                           |
| RSpec     | 3.13.2  | test framework                         |
| SimpleCov | 0.22.0  | test coverage                          |
| Standard  | 1.54.0  | linter / formatter (`standardrb`)      |

Gem versions are pinned in `Gemfile.lock`; `Gemfile` constrains Nokogiri `~> 1.19`, RSpec `~> 3.13`, SimpleCov `~> 0.22`, and Standard `~> 1.0`. Run `bundle install`, then `bundle exec rake` to run the specs and the linter together (the default task); or invoke them individually with `bundle exec rspec` and `bundle exec standardrb`.
