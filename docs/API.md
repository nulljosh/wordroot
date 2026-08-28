# API

Wordroot has no HTTP API of its own — there is no backend. The web app queries Wiktionary's
public REST API directly from the browser:

- `https://en.wiktionary.org/api/rest_v1/page/definition/{word}` — definitions, keyed by the
  language of each section on the page (`{"en": [...], "fr": [...]}`); Wordroot reads only the
  key for the selected word language
- `https://en.wiktionary.org/w/api.php?action=parse&page={word}&prop=wikitext&format=json&origin=*` — wikitext, narrowed client-side to the selected language's `==Section==` and then parsed for the etymology ancestor chain

Every request goes to the **English** Wiktionary whatever the interface language is: it holds
entries for thousands of languages under one consistent set of etymology templates, while the
other editions each use their own incompatible markup.

## WebMCP

`web/webmcp.js` registers tools via `document.modelContext` (the WebMCP API) so an agent
visiting the page can look words up the same way the UI does.

### Read-only

| tool | what it does |
|---|---|
| `lookup_word` | Full lookup for a word: definitions + etymology chain. Takes an optional `language` code; defaults to the language the page is set to. Drives the on-page UI when the language matches what is on screen. |
| `get_etymology` | Just the ancestor word chain for a word (no definitions). Takes the same optional `language`. |
| `get_word_of_the_day` | Returns today's word of the day, in the page's current word language. No arguments. |
| `list_languages` | The languages words can be looked up in, and which one the page is set to. Call this first to get valid `language` codes. |

No tool requires confirmation. Every tool only reads from Wiktionary's public API and reflects
data back to the caller (or the page) — nothing is stored, mutated, or sent anywhere else.
