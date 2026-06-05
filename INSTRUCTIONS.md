# Instructions

Extract a Google paintings carousel from a saved HTML page into JSON. See `DESIGN.md` for the approach.

## Setup

```sh
bundle install
```

Requires Ruby 4.0 (pinned in `.ruby-version`; see `DESIGN.md` Section 7 for versions).

## Tests + lint

```sh
bundle exec rake             # specs + linter (the default task)
```

Or individually:

```sh
bundle exec rspec            # specs (prints SimpleCov coverage; report in coverage/)
bundle exec standardrb       # lint  (add --fix to auto-correct)
```

## Extract from the command line

Print the JSON for any of the fixture pages:

```sh
bin/extract files/van-gogh-paintings.html
```

Swap in `files/pablo-picasso-paintings.html` or `files/leonardo-da-vinci-paintings.html`.

## Use it from a console

`bin/console` opens an IRB session with the classes already loaded:

```ruby
result = SearchResult.from_file("files/van-gogh-paintings.html")
result.artworks.size        # => 47
result.to_h["artworks"].first
```
