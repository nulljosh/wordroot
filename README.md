<img src="icon.svg" width="80">

# Wordroot

![version](https://img.shields.io/badge/version-0.1.0-blue)

Dictionary with deep etymology. Trace any word back through Latin, Greek, and Proto-Indo-European with an interactive etymology tree and cognate links.

## Why
No app combines clean dictionary UX with real etymology visualization. The big dictionary apps have ads and no etymology; the one etymology app is mediocre.

## Architecture
<img src="architecture.svg" width="600">

- **pipeline/** — Python (stdlib only) parser: Wiktionary → etymology graph → SQLite
- **ios/** — SwiftUI multiplatform (iOS + Mac), xcodegen
- **web/** — static frontend, shared dataset
- **i18n/** — one string catalog for every surface (see below)

## Data
Wiktionary (CC-BY-SA) parsed into a word/edge graph, WordNet fills gaps. No OED, no Etymonline text, no LLM-generated etymologies.

## Languages

Two independent axes:

- **Interface language** — the app's own chrome, in 12 languages: English, Spanish, French,
  German, Portuguese, Italian, Dutch, Russian, Japanese, Simplified Chinese, Korean and
  Arabic (right-to-left). Detected from the browser or system on first run, then overridable
  from a picker and remembered.
- **Word language** — the language of the word you are looking up, out of 30 including Latin,
  Ancient Greek, Sanskrit, Old English and Old Norse. Defaults to the interface language where
  a dictionary exists.

Lookups always go to the English Wiktionary whatever the interface language is: it carries
entries for thousands of languages under one consistent set of etymology templates (`inh`,
`der`, `bor`), while each other edition uses its own incompatible markup. The word language
selects which `==Language==` section of the page to read — so `chat` returns Middle English
ancestry in English and Old French ancestry in French, rather than whichever appears first.
Definitions are Wiktionary's own glosses and are written in English.

`i18n/strings.json` is the only place a string is written. `scripts/gen-i18n.py` generates
`web/i18n.js`, `landing/i18n.js` and `ios/Sources/Localized.swift` from it; those three are
generated files and must not be hand-edited. `scripts/build-site.sh` refuses to build if they
are stale.

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
Wordroot has no backend/HTTP API of its own; see [docs/API.md](docs/API.md) for the Wiktionary
endpoints it queries directly and the read-only WebMCP tools the web app registers.
