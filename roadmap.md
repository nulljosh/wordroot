# Etyma Roadmap

App Store record: **Wordroot** (app id 6794988021, bundle `com.heyitsmejosh.etyma`)
Web: https://etyma.heyitsmejosh.com (Cloudflare Pages project `etyma`)

## Ship state 2026-08-11
iOS 1.0 validates clean (`asc validate` → 0 blocking). Done this pass:
- content rights, copyright, categories (REFERENCE / EDUCATION), age rating (all NONE + profanity INFREQUENT_OR_MILD — dictionary surfaces vulgar entries)
- en-US description / keywords / support + marketing URL / subtitle / privacy URL
- review details (no demo account needed), build 037486c9 attached, encryption compliance = exempt
- screenshots: iPhone 6.5" ×3, iPad Pro 12.9" ×2
- pricing schedule (free) + availability (all territories, auto-add new)
- landing page + `/privacy.html` deployed

### Blocked
- [ ] **App Privacy data usages not published** — the only thing stopping submission. Public API cannot do it; needs `asc web privacy publish`, which needs a live ASC web session. Run `asc-login` (2FA prompt), then:
  `asc web privacy pull --app 6794988021` → declare "Data Not Collected" → `asc web privacy publish --app 6794988021`
  Then: `asc review submit --app 6794988021 --version 1.0 --platform IOS --build 037486c9-d9b0-4b4f-972f-a1eb449ce8fa --confirm`
- [ ] Note: Guideline 5.6 suspension freezes submissions until 2026-08-18 (see other apps).

### macOS 1.0
Version record exists with the same metadata/review details, but has **no build and no screenshots**. Needs archive → export → `asc builds upload` → Mac screenshots (1280×800 or 2880×1800) → submit. Blocked behind the same App Privacy gate.

## Backlog
- [ ] Full Wiktionary dump parse still pending (v1 uses live REST API instead) — large scoped feature, needs its own session
