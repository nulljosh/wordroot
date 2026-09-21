Note: no karma/flair gate found, frame as "built X to solve Y" not an ad.

Title: I built a static web dictionary that traces word etymology instead of just defining words

Body:
Kept falling into Wiktionary rabbit holes trying to trace a word back to its root, so I built Wordroot to do it directly. Type a word, get the definition, and get the etymology chain: Old English, Latin, Greek, back to Proto-Indo-European where it's known.

The web app is a static frontend over a shared dataset. The etymology itself comes from a Python stdlib-only pipeline that parses Wiktionary's `inh`/`der`/`bor`/`cog` wikitext templates into a graph instead of asking a model to generate plausible-sounding ancestry.

Free to use, no login. Also ships native on iOS and Mac for $0.99. Curious what other devs think of the deterministic-parse-over-LLM approach for this kind of data.

wordroot.heyitsmejosh.com
