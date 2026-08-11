#!/usr/bin/env python3
"""v0: fetch sample words from Wiktionary API, extract etymology chains, write wordroot.sqlite.

ponytail: REST API + regex over wikitext for ~20 words; full dump parse with
proper template handling is build-order step 2.
"""
import json
import re
import sqlite3
import urllib.parse
import urllib.request
from pathlib import Path

SAMPLE_WORDS = [
    "water", "mother", "father", "night", "star", "fire", "heart", "name",
    "new", "three", "foot", "tooth", "sun", "moon", "wind", "snow",
    "salt", "wolf", "yoke", "mead",
]

DB = Path(__file__).parent / "wordroot.sqlite"
API = "https://en.wiktionary.org/w/api.php?action=parse&prop=wikitext&format=json&page={}"

# etymology templates: {{inh|en|enm|water}}, {{der|...}}, {{bor|...}}, {{cog|...}}
LINK_RE = re.compile(r"\{\{(inh\+?|der\+?|bor\+?|cog)\|[^|]*\|([^|}]+)\|([^|}]*)")
# {{root|en|ine-pro|*wed-}} — lang is param 2, root form param 3
ROOT_RE = re.compile(r"\{\{root\|[^|]*\|([^|}]+)\|([^|}]+)")

REL = {"inh": "inherited", "der": "derived", "bor": "borrowed", "cog": "cognate"}


def fetch_wikitext(word):
    url = API.format(urllib.parse.quote(word))
    req = urllib.request.Request(url, headers={"User-Agent": "wordroot-app/0.1 (trommatic@icloud.com)"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    return data.get("parse", {}).get("wikitext", {}).get("*", "")


def etymology_section(wikitext):
    m = re.search(r"===\s*Etymology[^=]*===\n(.*?)(?=\n==|\Z)", wikitext, re.S)
    return m.group(1) if m else ""


def main():
    con = sqlite3.connect(DB)
    con.executescript(
        """
        DROP TABLE IF EXISTS words;
        DROP TABLE IF EXISTS edges;
        CREATE TABLE words (word TEXT, lang TEXT, etymology TEXT, PRIMARY KEY (word, lang));
        CREATE TABLE edges (word TEXT, lang TEXT, ancestor TEXT, ancestor_lang TEXT, relation TEXT);
        """
    )
    for word in SAMPLE_WORDS:
        ety = etymology_section(fetch_wikitext(word))
        con.execute("INSERT OR REPLACE INTO words VALUES (?,?,?)", (word, "en", ety.strip()))
        for kind, lang, ancestor in LINK_RE.findall(ety):
            if ancestor:
                con.execute(
                    "INSERT INTO edges VALUES (?,?,?,?,?)",
                    (word, "en", ancestor.strip(), lang.strip(), REL[kind.rstrip("+")]),
                )
        for lang, form in ROOT_RE.findall(ety):
            con.execute("INSERT INTO edges VALUES (?,?,?,?,?)", (word, "en", form.strip(), lang.strip(), "root"))
        print(f"{word}: {con.execute('SELECT COUNT(*) FROM edges WHERE word=?', (word,)).fetchone()[0]} edges")
    con.commit()
    con.close()
    print(f"wrote {DB}")


if __name__ == "__main__":
    main()
