# Wordroot

Dictionary + etymology app. Killer feature: interactive etymology tree (word → Latin/Greek/PIE, cognate links).

## Stack
- `pipeline/` — Python 3, stdlib only. Wiktionary REST API (v0) → later full dump parse. Output: `wordroot.sqlite` (`words`, `edges` tables).
- `ios/` — SwiftUI multiplatform via xcodegen, bundle `com.heyitsmejosh.etyma`, iOS + Mac targets.
- `web/` — static HTML for now, shared dataset.

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
