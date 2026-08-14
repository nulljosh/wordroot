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

### macOS 1.0 — build in progress, 1 error left
Archive + export + upload all work (`asc builds upload --app 6794988021 --pkg ... --version 1.0 --build-number N`). Three uploads so far:
- build 1 — FAILED (90242 + 90296)
- build 2 — FAILED (90242 + 90296)
- build 3 — FAILED (90242 only; sandbox fixed by `ios/Wordroot.entitlements`)

**Remaining: ITMS-90242.** Root cause confirmed by `codesign -dv` on the archive: the .app is signed
`Authority=Apple Development: trommatic@icloud.com` — a *development* cert. The Mac App Store needs
**3rd Party Mac Developer Application** (that identity IS in the keychain, along with the Installer one;
the .pkg installer signature is already correct). Automatic signing is picking the dev cert.

Fix next session: force the distribution identity, e.g. in `ios/project.yml` set
`CODE_SIGN_IDENTITY: "3rd Party Mac Developer Application"` (with `CODE_SIGN_STYLE: Manual` + a Mac App Store
provisioning profile), or pass `-allowProvisioningUpdates` with an explicit distribution profile at archive time.
Then re-archive → export with `ExportOptions` containing `installerSigningCertificate` → upload as build 4.

Also still needed: **Mac screenshots** (1280×800 or 2880×1800). Blocked in practice — synthetic clicks/keystrokes
don't reach the app window, and UI-scripting is against standing preference. The default word-of-the-day ("mother")
also renders a vulgar Wiktionary sense, so a screenshot must be of a searched word, which needs that input path.

Same Aug 18 freeze applies to submitting either platform.

## Backlog
- [ ] Full Wiktionary dump parse still pending (v1 uses the live REST API instead) — large scoped feature, needs its own session
- [ ] Cloudflare Pages project is still named `etyma` (Pages projects can't be renamed; would need a new project + domain move — cosmetic, low priority)

> Resume note (2026-08-11): a `wip: partial work from /work notes ingest` commit holds unfinished, unverified changes for the items above. Review `git show HEAD` before building on it — it was committed mid-flight, not reviewed, and is unpushed.

## From Apple Notes (imported 2026-08-13)
- [ ] Migrate Wordroot from Vercel to Cloudflare
