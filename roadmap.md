# Etyma Roadmap

## Stashed 2026-07-10
- [x] Ship iOS: build succeeded 2026-07-10 (Lookup-style v1 committed 481647b) — ASC app record created 2026-07-26 (app ID 6794988021, bundle com.heyitsmejosh.etyma). App Store display name "Wordroot" (name "Etyma", "Etymo", "Cognate" all taken by other developers) — remaining: sim visual test, icon, screenshots, submit
- [ ] Full Wiktionary dump parse still pending (v1 uses live REST API instead) — large scoped feature (build-order step 2, "the real risk gate" per CLAUDE.md), not a quick pass; needs its own session

## From App Store.pdf (imported 2026-07-28)
- [x] Create an app icon for Wordroot — DONE 2026-07-28: reused existing `icon.svg` (word-node/root-branch motif, already using a distinct dark-blue/green palette, not previously wired into the iOS asset catalog). Generated 16–1024px PNGs into `ios/Sources/Assets.xcassets/AppIcon.appiconset/`, wired `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in project.yml, xcodegen regenerated, iOS build succeeds. Not resubmitted to ASC this pass — asset only.
