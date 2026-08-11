# Wordroot Roadmap

App Store record: **Wordroot** (app id 6794988021, bundle `com.heyitsmejosh.etyma` — Apple-locked, keeps the old name)
Repo: `nulljosh/wordroot` · folder `~/Documents/Code/wordroot` (renamed from etyma 2026-08-11)
Web: https://wordroot.heyitsmejosh.com (Cloudflare Pages project is still named `etyma`; `etyma.heyitsmejosh.com` also still resolves)

## Ship state 2026-08-11
iOS 1.0 is **fully submission-ready** — `asc validate` returns 0 blocking errors and App Privacy is published. Done this pass:
- content rights, copyright, categories (REFERENCE / EDUCATION), age rating (all NONE + profanity INFREQUENT_OR_MILD — a dictionary surfaces vulgar entries)
- en-US description / keywords / support + marketing URL / subtitle / privacy URL
- review details (no demo account), build 037486c9 attached, encryption compliance = exempt
- screenshots: iPhone 6.5" ×3, iPad Pro 12.9" ×2
- pricing schedule (free) + availability in all territories
- App Privacy published as DATA_NOT_COLLECTED
- full Etyma → Wordroot rename (app target, sources, site, docs, repo, folder, portfolio link)

### Blocked
- [ ] **Do not submit until 2026-08-18** — Guideline 5.6 account-level suspension freeze, see `~/Documents/Code/CLAUDE.md`. On/after Aug 18 the whole submission is one command:
  `asc review submit --app 6794988021 --version 1.0 --platform IOS --build 037486c9-d9b0-4b4f-972f-a1eb449ce8fa --confirm`

### macOS 1.0
Version record has the same metadata + review details, but **no build and no screenshots**. Needs archive → export → `asc builds upload` → Mac screenshots (1280×800 or 2880×1800) → submit. Same Aug 18 freeze applies.

## Backlog
- [ ] Full Wiktionary dump parse still pending (v1 uses the live REST API instead) — large scoped feature, needs its own session
- [ ] Cloudflare Pages project is still named `etyma` (Pages projects can't be renamed; would need a new project + domain move — cosmetic, low priority)
