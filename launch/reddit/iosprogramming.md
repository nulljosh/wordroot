Note: use the "Show and Tell" flair. Check the pinned weekly self-promo thread first, a standalone post is safer once you've commented there a few times.

Title: Wordroot, an etymology dictionary for iOS and Mac (SwiftUI, xcodegen)

Body:
Wanted a dictionary that actually shows where a word came from instead of just defining it, so I built Wordroot. It looks up any English word and shows the etymology chain back through Old English, Latin, Greek, to Proto-Indo-European where the data supports it.

SwiftUI multiplatform target via xcodegen, one codebase for iOS and Mac. The etymology data comes from a Python stdlib-only pipeline that parses Wiktionary's own wikitext templates into a graph rather than trusting a model to guess ancestry.

The web version is free. The App Store version is $0.99 upfront, no subscription. Would love feedback from anyone who's shipped a reference/dictionary-style app on how you handled offline data versus live lookups.

wordroot.heyitsmejosh.com · https://apps.apple.com/app/id6794988021
