#!/usr/bin/env python3
"""Parser unit tests (offline) plus a smoke check of wordroot.sqlite when one has been built."""
import sqlite3
import sys
from pathlib import Path

from parse import catalog, etymology_section, language_section, sample_words, word_languages

# One page, two languages, two unrelated histories — the case that makes section scoping
# load-bearing rather than cosmetic.
CHAT = """==English==

===Etymology===
From {{inh|en|enm|chat}}, from {{der|en|ang|ceatian}}.

===Noun===
Informal talk.

==French==

===Etymology===
From {{inh|fr|fro|chat}}, from {{inh|fro|la|cattus}}.

===Noun===
Cat.
"""


def test_language_section_stops_at_the_next_language():
    english = language_section(CHAT, "English")
    assert "ceatian" in english
    assert "cattus" not in english, "French section leaked into English"


def test_language_section_missing_language_is_empty():
    assert language_section(CHAT, "Japanese") == ""


def test_etymology_is_read_from_the_requested_language():
    assert "ceatian" in etymology_section(CHAT, "English")
    assert "cattus" in etymology_section(CHAT, "French")
    assert etymology_section(CHAT, "Japanese") == ""


def test_every_word_list_names_a_selectable_language():
    codes = set(word_languages())
    extra = set(catalog()["wordsOfTheDay"]) - codes
    assert not extra, f"word lists for unselectable languages: {sorted(extra)}"


def test_english_sample_words_are_present():
    assert "water" in sample_words("en")
    assert sample_words("cy") == [], "no list shipped for Welsh"


def smoke_test_database():
    db = Path(__file__).parent / "wordroot.sqlite"
    if not db.exists():
        print("skip: wordroot.sqlite not built (run parse.py)")
        return
    con = sqlite3.connect(db)
    langs = {r[0] for r in con.execute("SELECT ancestor_lang FROM edges WHERE word='water'")}
    assert "ine-pro" in langs, f"water edges missing PIE, got: {langs}"
    n = con.execute("SELECT COUNT(*) FROM edges").fetchone()[0]
    assert n >= 20, f"too few edges overall: {n}"
    print(f"ok: water→PIE present, {n} edges total")


if __name__ == "__main__":
    failed = 0
    for name, fn in sorted(globals().items()):
        if not name.startswith("test_"):
            continue
        try:
            fn()
            print(f"ok   {name}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL {name}: {e}")
    smoke_test_database()
    sys.exit(1 if failed else 0)
