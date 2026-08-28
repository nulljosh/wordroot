#!/bin/sh
# ponytail: compose the Pages site — marketing landing at /, web app at /app
set -e
cd "$(dirname "$0")/.."
# The i18n bundles are generated; a stale one ships strings that no longer match the catalog.
python3 scripts/gen-i18n.py --check
rm -rf dist && mkdir -p dist/app
cp -R landing/. dist/
cp -R web/. dist/app/
rm -rf dist/app/.vercel dist/app/.wrangler dist/app/.env.local
echo "built dist/ (landing at /, app at /app)"
