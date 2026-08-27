# API

Wordroot has no HTTP API of its own — there is no backend. The web app queries Wiktionary's
public REST API directly from the browser:

- `https://en.wiktionary.org/api/rest_v1/page/definition/{word}` — definitions
- `https://en.wiktionary.org/w/api.php?action=parse&page={word}&prop=wikitext&format=json&origin=*` — wikitext, parsed client-side for the etymology ancestor chain

## WebMCP

`web/webmcp.js` registers tools via `document.modelContext` (the WebMCP API) so an agent
visiting the page can look words up the same way the UI does.

### Read-only

| tool | what it does |
|---|---|
| `lookup_word` | Full lookup for a word: definitions + etymology chain. Also drives the on-page UI so the user sees the same result. |
| `get_etymology` | Just the ancestor word chain for a word (no definitions). |
| `get_word_of_the_day` | Returns today's word of the day. No arguments. |

No tool requires confirmation. Every tool only reads from Wiktionary's public API and reflects
data back to the caller (or the page) — nothing is stored, mutated, or sent anywhere else.
