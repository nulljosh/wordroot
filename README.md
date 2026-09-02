<img src="icon.svg" width="80">

# Wordroot

![version](https://img.shields.io/badge/version-0.1.0-blue)

**Live:** https://wordroot.heyitsmejosh.com

Where did that word come from? Look it up and follow it back, through Latin, Greek, all the way to Proto-Indo-European. A dictionary with the roots showing.

## Why
No app pairs a clean dictionary with real etymology. The big dictionary apps have ads and no history. The one etymology app is mediocre.

## Architecture
<img src="architecture.svg" width="600">

- **pipeline/**: a Python parser, stdlib only. Wiktionary in, etymology graph out, SQLite on disk
- **ios/**: SwiftUI for iOS and Mac, xcodegen
- **web/**: static frontend on the same dataset
- **i18n/**: one string catalog for every surface (below)

## Data
Wiktionary (CC-BY-SA), parsed into a graph of words and edges. WordNet fills gaps. No OED. No Etymonline. No etymology a model made up.

## Languages

Two independent axes:

- **Interface language**: the app's own chrome, in 12 languages. English, Spanish, French,
  German, Portuguese, Italian, Dutch, Russian, Japanese, Simplified Chinese, Korean and
  Arabic, right to left. Detected on first run, then yours to change, and remembered.
- **Word language**: the language of the word you're looking up. 30 of them, including Latin,
  Ancient Greek, Sanskrit, Old English and Old Norse. Defaults to the interface language when
  a dictionary exists for it.

**Etymology** always comes from the English Wiktionary, whatever the interface language. It
covers thousands of languages under one set of templates (`inh`, `der`, `bor`). Every other
edition uses its own markup. The word language picks which `==Language==` section to read, so
`chat` gives Middle English ancestry in English and Old French ancestry in French, not
whichever comes first.

**Definitions** are prose, so the edition decides the language. Wordroot asks your own edition
first (`fr.wiktionary` defines in French) and falls back to English, the only edition sure to
answer. Both requests go out together, so the fallback costs no extra round trip. An edition
that doesn't serve definitions isn't asked again that session. When English was the fallback,
the entry says so and links to your own Wiktionary.

`i18n/strings.json` is the only place a string is written. `scripts/gen-i18n.py` generates
`web/i18n.js`, `landing/i18n.js` and `ios/Sources/Localized.swift` from it. Don't edit those
three by hand. `scripts/build-site.sh` refuses to build if they're stale.

## Run
```sh
python3 scripts/gen-i18n.py           # regenerate the i18n bundles after editing the catalog
python3 scripts/gen-i18n.py --check   # verify they are current

python3 pipeline/parse.py             # builds wordroot.sqlite from English sample words
python3 pipeline/parse.py --lang de   # ...or German, added alongside
python3 pipeline/test_parse.py

node scripts/test-web.mjs             # web app + landing page: i18n and lookup
```

## License
MIT © 2026 Joshua Trommel

## Whitepaper

[Technical whitepaper](WHITEPAPER.md)

## API and agent tools
Wordroot has no backend of its own. [docs/API.md](docs/API.md) lists the Wiktionary endpoints it
calls directly and the read-only WebMCP tools the web app registers.
