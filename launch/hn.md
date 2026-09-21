Show HN: Wordroot – Look up a word and follow it back to its root

Dictionaries stop at the definition. The interesting part is the chain behind it. Wordroot looks up any English word and walks it back: Middle English, Old English, Latin, Greek, all the way to Proto-Indo-European where it is known.

The etymology comes from Wiktionary's own wikitext, not a model. The pipeline parses the `inh`, `der`, `bor` and `cog` templates in each Etymology section with a stdlib-only Python script and builds a word/language graph, no LLM guessing at ancestry it never verified. An LLM will happily invent a plausible-looking etymology chain, and licensed sources like the OED can't be redistributed at all, so a deterministic parse of the open wikitext was the only path that stays honest.

Web is free at wordroot.heyitsmejosh.com, source on GitHub. The App Store version is $0.99 upfront.
