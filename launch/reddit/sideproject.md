Note: no karma/flair gate. Public launch post, App Store link fine.

Title: A dictionary that shows where words come from

Body:
Every time I fell into a Wiktionary hole chasing a word back to its root, I wished there was just an app for it. Normal dictionaries stop at the definition. The interesting part, where the word actually came from, is buried in wikitext markup most people never see.

So I built Wordroot. Look up any English word and it walks the chain back: Middle English, Old English, Latin, Greek, Proto-Indo-European where it's known, with cognates along the way.

Built with a Python stdlib-only pipeline that parses Wiktionary's etymology templates into a graph, SwiftUI for iOS and Mac, and a static web build sharing the same dataset.

Free on the web. The App Store version is $0.99 upfront. Feedback welcome, especially on words that come back with a thin or wrong chain.

wordroot.heyitsmejosh.com
