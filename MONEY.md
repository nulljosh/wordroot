# Wordroot Money

How Wordroot makes money. The fleet-wide ledger is `GTM.md` in the Code root.

## Price

$0.99 upfront on the App Store.

## Rail

App Store paid download. Apple keeps 15%, so each sale pays out $0.84.

## Why

A reference app. Buy it once, look things up forever. The web version stays free, so the landing page is the trial and the store is the checkout.

## Next

Nothing to build. Watch App Store Connect sales. If a month passes with installs on the web and none in the store, go back to free.

## Change it

`asc pricing schedule create --app 6794988021 --price 0.99 --base-territory USA --start-date YYYY-MM-DD`. Swap `--price 0.99` for `--free` to revert. No build, no review.

Anyone who got Wordroot while it was free keeps it free. Only new customers pay.

*ASC 6794988021. Set 2026-09-20.*
