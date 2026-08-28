# Wordroot

Dictionary + etymology app. Killer feature: interactive etymology tree (word → Latin/Greek/PIE, cognate links).

## Stack
- `pipeline/` — Python 3, stdlib only. Wiktionary REST API (v0) → later full dump parse. Output: `wordroot.sqlite` (`words`, `edges` tables).
- `ios/` — SwiftUI multiplatform via xcodegen, bundle `com.heyitsmejosh.etyma`, iOS + Mac targets.
- `web/` — static HTML for now, shared dataset.
- `i18n/strings.json` — the single source of truth for every translated string, the 12 interface
  languages and the 30 word languages. `scripts/gen-i18n.py` generates `web/i18n.js`,
  `landing/i18n.js` and `ios/Sources/Localized.swift`; never hand-edit those three.

## Language rules
- Two axes, kept separate: interface language (UI chrome) and word language (the language of
  the word being looked up).
- All lookups hit **en.wiktionary.org** regardless of interface language — it is the only
  edition whose `inh`/`der`/`bor` templates the parser understands, and it covers thousands of
  languages. The word language picks the `==Section==` to read, never the site to fetch.
- Scope etymology parsing to the language section. The first `===Etymology===` on a page
  belongs to whichever language sorts first, which for a word like `chat` is the wrong one.
- Never build a sentence by concatenating translated fragments; word order differs across the
  twelve locales. Ancestor on one line, `relation · language` beneath.
- Add a string to `i18n/strings.json` in all 12 locales or not at all — a half-filled key
  falls back to English silently.

## Data rules
- Wiktionary dumps (CC-BY-SA, attribute) + WordNet for gaps.
- NO OED (cost), NO Etymonline text (copyright), NO LLM-generated etymologies (hallucinates).

## Build order
1. ✅ v0 scaffold + sample parse (REST API, ~20 words)
2. Full Wiktionary dump parse — the real risk gate (wikitext etymology templates: `inh`, `der`, `bor`, `cog`)
3. iOS lookup UI
4. Etymology tree UI
5. Mac + web

## Pricing (later)
Freemium: $3/mo or $30 lifetime. Paid = offline, trees, collections.

## Reality check
Niche, low revenue ceiling — portfolio piece.
