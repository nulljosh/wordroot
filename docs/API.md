# API

Wordroot has no HTTP API of its own — there is no backend. The web app queries Wiktionary's
public REST API directly from the browser:

- `https://{edition}.wiktionary.org/api/rest_v1/page/definition/{word}` — definitions, keyed by
  the language of each section on the page (`{"en": [...], "fr": [...]}`); Wordroot reads only
  the key for the selected word language
- `https://en.wiktionary.org/w/api.php?action=parse&page={word}&prop=wikitext&format=json&origin=*` — wikitext, narrowed client-side to the selected language's `==Section==` and then parsed for the etymology ancestor chain

**Definitions** are requested from the reader's own edition and from `en` together, and the
reader's own edition wins when it answers — its glosses are written in their language. A
non-404 response means that edition does not serve the endpoint, and it is not asked again for
the rest of the session. Availability varies by edition and the English one is the backstop.

**Etymology** is always parsed from the **English** Wiktionary whatever the interface language
is: it holds entries for thousands of languages under one consistent set of etymology
templates, while the other editions each use their own incompatible markup.

## WebMCP

`web/webmcp.js` registers tools via `document.modelContext` (the WebMCP API) so an agent
visiting the page can look words up the same way the UI does.

### Read-only

| tool | what it does |
|---|---|
| `lookup_word` | Full lookup for a word: definitions + etymology chain. Takes an optional `language` code; defaults to the language the page is set to. Returns `definitionsLanguage` — the edition that wrote the glosses, and so the language they are in. Drives the on-page UI when the language matches what is on screen. |
| `get_etymology` | Just the ancestor word chain for a word (no definitions). Takes the same optional `language`. |
| `get_word_of_the_day` | Returns today's word of the day, in the page's current word language. No arguments. |
| `list_languages` | The languages words can be looked up in, and which one the page is set to. Call this first to get valid `language` codes. |

No tool requires confirmation. Every tool only reads from Wiktionary's public API and reflects
data back to the caller (or the page) — nothing is stored, mutated, or sent anywhere else.

## HTTP API (Cloudflare Pages Functions)

Wordroot now has a server surface at `https://wordroot.heyitsmejosh.com`. It reads
Wiktionary live — there is no database — and both surfaces call the same `callTool()` in
`src/lib/tools.js`, so REST and MCP cannot describe different behaviour.

### REST (read-only, `GET`)

| Endpoint | Returns |
|---|---|
| `/api` | The endpoint list and tool names. |
| `/api/languages` | The supported word languages, as codes and names. |
| `/api/word/:word?lang=` | Definitions + etymology chain. |
| `/api/definitions/:word?lang=` | Definitions only, grouped by part of speech. |
| `/api/etymology/:word?lang=` | Ancestors only (`inherited` / `derived` / `borrowed`). |

`lang` accepts a code (`la`) or a section name (`Latin`); it defaults to English. An unknown
language is a 400 naming the mistake, not a silent fall back to English on the wrong word.

### MCP

`POST /mcp`, JSON-RPC, stateless. Tools: `lookup_word`, `get_definitions`, `get_etymology`,
`list_languages`. All read-only — nothing here is stored or mutated.

Content is Wiktionary's, CC BY-SA 4.0; every `lookup_word` response carries its source URL.
