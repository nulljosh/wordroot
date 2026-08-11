#!/usr/bin/env python3
"""Smoke check: 'water' must trace back to Proto-Indo-European (lang code ine-pro)."""
import sqlite3
from pathlib import Path

con = sqlite3.connect(Path(__file__).parent / "wordroot.sqlite")
langs = {r[0] for r in con.execute("SELECT ancestor_lang FROM edges WHERE word='water'")}
assert "ine-pro" in langs, f"water edges missing PIE, got: {langs}"
n = con.execute("SELECT COUNT(*) FROM edges").fetchone()[0]
assert n >= 20, f"too few edges overall: {n}"
print(f"ok: water→PIE present, {n} edges total")
