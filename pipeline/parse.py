#!/usr/bin/env python3
"""v0: fetch sample words from Wiktionary API, extract etymology chains, write wordroot.sqlite.

ponytail: REST API + regex over wikitext for ~20 words; full dump parse with
proper template handling is build-order step 2.

Words are looked up in a chosen language (`--lang`, default English). The English Wiktionary
carries entries for thousands of languages under one consistent set of etymology templates,
so the language selects which `==Section==` of a page to read rather than which site to fetch.
"""
import argparse
import json
import re
import sqlite3
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "i18n" / "strings.json"
DB = Path(__file__).parent / "wordroot.sqlite"
API = "https://en.wiktionary.org/w/api.php?action=parse&prop=wikitext&format=json&page={}"

# etymology templates: {{inh|en|enm|water}}, {{der|...}}, {{bor|...}}, {{cog|...}}
LINK_RE = re.compile(r"\{\{(inh\+?|der\+?|bor\+?|cog)\|[^|]*\|([^|}]+)\|([^|}]*)")
# {{root|en|ine-pro|*wed-}} — lang is param 2, root form param 3
ROOT_RE = re.compile(r"\{\{root\|[^|]*\|([^|}]+)\|([^|}]+)")

REL = {"inh": "inherited", "der": "derived", "bor": "borrowed", "cog": "cognate"}


def catalog():
    """Language metadata and the sample word lists, shared with the web and Apple apps."""
    with open(CATALOG, encoding="utf-8") as f:
        return json.load(f)


def word_languages():
    """code -> ==Section== heading that language uses on the English Wiktionary."""
    return {w["code"]: w["section"] for w in catalog()["wordLanguages"]}


def sample_words(lang):
    """The word-of-the-day list for `lang` — the same words the apps rotate through."""
    return catalog()["wordsOfTheDay"].get(lang, [])


def fetch_wikitext(word):
    url = API.format(urllib.parse.quote(word))
    req = urllib.request.Request(url, headers={"User-Agent": "wordroot-app/0.1 (trommatic@icloud.com)"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    return data.get("parse", {}).get("wikitext", {}).get("*", "")


def language_section(wikitext, name):
    """Body of the ``==Name==`` section, or "". Stops at the next level-2 heading.

    Without this, a word spelled the same in several languages ("chat") yields whichever
    etymology happens to appear first on the page — often somebody else's.
    """
    m = re.search(rf"^==\s*{re.escape(name)}\s*==\s*$", wikitext, re.M)
    if not m:
        return ""
    after = wikitext[m.end():]
    end = re.search(r"^==[^=]", after, re.M)
    return after[: end.start()] if end else after


def etymology_section(wikitext, section="English"):
    body = language_section(wikitext, section)
    m = re.search(r"===\s*Etymology[^=]*===\n(.*?)(?=\n==|\Z)", body, re.S)
    return m.group(1) if m else ""


def main(argv=None):
    langs = word_languages()
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--lang", default="en", choices=sorted(langs),
                    help="language of the words to parse (default: en)")
    ap.add_argument("--words", nargs="+", help="override the sample word list")
    args = ap.parse_args(argv)

    words = args.words or sample_words(args.lang)
    if not words:
        sys.exit(f"no sample words for {args.lang!r}; pass --words explicitly")
    section = langs[args.lang]

    con = sqlite3.connect(DB)
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS words (word TEXT, lang TEXT, etymology TEXT, PRIMARY KEY (word, lang));
        CREATE TABLE IF NOT EXISTS edges (word TEXT, lang TEXT, ancestor TEXT, ancestor_lang TEXT, relation TEXT);
        """
    )
    # Only this language's rows are rebuilt, so parsing German after English adds to the
    # graph instead of replacing it.
    con.execute("DELETE FROM words WHERE lang=?", (args.lang,))
    con.execute("DELETE FROM edges WHERE lang=?", (args.lang,))

    for word in words:
        ety = etymology_section(fetch_wikitext(word), section)
        con.execute("INSERT OR REPLACE INTO words VALUES (?,?,?)", (word, args.lang, ety.strip()))
        for kind, lang, ancestor in LINK_RE.findall(ety):
            if ancestor:
                con.execute(
                    "INSERT INTO edges VALUES (?,?,?,?,?)",
                    (word, args.lang, ancestor.strip(), lang.strip(), REL[kind.rstrip("+")]),
                )
        for lang, form in ROOT_RE.findall(ety):
            con.execute("INSERT INTO edges VALUES (?,?,?,?,?)", (word, args.lang, form.strip(), lang.strip(), "root"))
        n = con.execute(
            "SELECT COUNT(*) FROM edges WHERE word=? AND lang=?", (word, args.lang)
        ).fetchone()[0]
        print(f"{word}: {n} edges")
    con.commit()
    con.close()
    print(f"wrote {DB} ({args.lang})")


if __name__ == "__main__":
    main()
