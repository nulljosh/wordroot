# Wordroot Technical Whitepaper

**v1.0** | August 2026

Where did that word come from?

A normal dictionary answers what a word means. It rarely answers why it looks
the way it does, and the etymology sources that do exist (OED, Etymonline)
sit behind a paywall or a copyright nobody can license casually. Wordroot
exists to make that answer free and explorable: look up a word and follow it
back through Latin, Greek and Proto-Indo-European, with cognates along the
way. Web plus SwiftUI on iOS and Mac. This paper is about the data pipeline,
because that's the part that decides whether the rest of the app can exist
honestly. The rest is detail.

## Etymology Graph Pipeline

The core bet is that etymology data can be extracted from Wiktionary wikitext
without an LLM and without licensed sources (no OED, no Etymonline), because
an LLM invents plausible-sounding ancestry it did not verify, and licensed
text can't be redistributed at all. The pipeline (`pipeline/parse.py`, Python
stdlib only) runs:

1. **Parse**: Wiktionary dump entries are scanned for `{{inh}}`, `{{der}}`,
   `{{bor}}`, and `{{cog}}` templates in the Etymology sections. Each template
   yields a directed edge: word → ancestor (inherited/derived/borrowed) or
   word ↔ cognate.
2. **Graph**: edges accumulate into a word/language graph. Nodes carry
   language code, script, and gloss; edges carry relation type.
3. **Store**: the graph is written to SQLite (`wordroot.sqlite`), one table for
   words, one for edges. WordNet fills definition gaps.

Chains are walked at query time by following inherit/derive edges ancestor-ward
until they terminate (usually at a PIE root). Cognates are the sibling set of
any node on the chain.

## Lookup

The shipped v1 is lookup-style: live Wiktionary API lookup with the etymology
chain rendered inline, on web and iOS. The offline SQLite dataset is the
long-term path, since a live API call is slower and a full local graph would
let the app work offline and answer instantly; live lookup keeps the app
useful before the full dump is processed rather than waiting on that
pipeline to finish before shipping anything. iOS 1.0 and macOS 1.0 both went
live on the App Store 2026-08-27.

## Data Licensing

Wiktionary content is CC-BY-SA and attributed. No OED text, no Etymonline
text, no LLM-generated etymologies, because the whole premise falls apart if
a chain looks sourced but isn't. If the graph doesn't have a real sourced
edge, the chain ends, no synthetic ancestry to fill the gap.

## Platforms

| Platform | Stack | Notes |
|----------|-------|-------|
| Web | Static frontend | Shared dataset |
| iOS / Mac | SwiftUI multiplatform, xcodegen | Live lookup + chain view |
| Pipeline | Python 3, stdlib only | `parse.py` + `test_parse.py` |

## License

MIT 2026, Joshua Trommel
