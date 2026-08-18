# Wordroot Roadmap

App Store record: **Wordroot** (app id 6794988021, bundle `com.heyitsmejosh.etyma` — Apple-locked, keeps the old name)
Repo: `nulljosh/wordroot` · folder `~/Documents/Code/wordroot` (renamed from etyma 2026-08-11)
Web: https://wordroot.heyitsmejosh.com (Cloudflare Pages project is still named `etyma`; `etyma.heyitsmejosh.com` also still resolves)

## Ship state 2026-08-17 (build 4 — name mismatch fixed)
iOS 1.0 is **submission-ready and now carries the right app name**. `asc validate` returns 0 errors /
0 warnings / 1 info (the known unverifiable App-Privacy advisory).

**Caught this pass:** the attached build was build 1, uploaded 2026-07-29 — *before* the 08-11
Etyma→Wordroot rename (`e10d481`). The target has no `CFBundleDisplayName` override and
`PRODUCT_NAME = $(TARGET_NAME)`, so that binary installed on the home screen as **"Etyma"** while the
App Store listing says **"Wordroot"**. Submitting it risked a name-mismatch rejection — a bad bet on an
account already under a 5.6 Code of Conduct suspension.

Fixed: bumped `CURRENT_PROJECT_VERSION` 3 → 4, regenerated with xcodegen, archived + uploaded
**build 4** (`f10786f8-b4a5-41d1-9441-a6b4c4fcd516`, `CFBundleName = Wordroot`), verified
`COMPLETE`/`VALID`/exempt via `asc builds uploads list`, and attached it to version 1.0.
Version state: `PREPARE_FOR_SUBMISSION`, no pending submission.

### Ship state 2026-08-11 (superseded above)
Done that pass:
- content rights, copyright, categories (REFERENCE / EDUCATION), age rating (all NONE + profanity INFREQUENT_OR_MILD — a dictionary surfaces vulgar entries)
- en-US description / keywords / support + marketing URL / subtitle / privacy URL
- review details (no demo account), build 037486c9 attached, encryption compliance = exempt
- screenshots: iPhone 6.5" ×3, iPad Pro 12.9" ×2
- pricing schedule (free) + availability in all territories
- App Privacy published as DATA_NOT_COLLECTED
- full Etyma → Wordroot rename (app target, sources, site, docs, repo, folder, portfolio link)

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

> Resume note (2026-08-11, triaged 2026-08-17): the `wip: partial work from /work notes ingest` commit
> (`765356f`) is **landing-page only** — `landing/index.html`, `landing/icon.svg`, `scripts/build-site.sh`,
> `.gitignore`. It touches no iOS source, so it is not a ship risk and did not affect build 4. It is pushed
> (`main` == `origin/main`), contrary to the old note. Still unreviewed as web work — needs its own pass.
