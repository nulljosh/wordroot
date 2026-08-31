// The one definition of what Wordroot does over the network. Both surfaces — the REST
// routes in functions/api/ and the MCP server in functions/mcp.js — call `callTool` from
// here, so they cannot drift apart.
//
// ponytail: no D1, no JSON dataset. Wiktionary is the dataset; the app already reads it
// live from the browser, so the server reads it live too. The only thing this adds over
// the client is a User-Agent Wikimedia actually wants, and CORS-free access for agents.
// Add storage when a rate limit or a latency number says to, not before.

import strings from '../../i18n/strings.json' with { type: 'json' };

const WIKI = 'https://en.wiktionary.org';
const UA = 'Wordroot/1.0 (https://wordroot.heyitsmejosh.com; trommatic@icloud.com)';

// Same templates the web app parses: inherited / derived / borrowed, each `{{inh|en|la|word}}`.
const LINK_RE = /\{\{(inh\+?|der\+?|bor\+?)\|[^|]*\|([^|}]+)\|([^|}]*)/g;
const REL = { inh: 'inherited', der: 'derived', bor: 'borrowed' };

// The same 30 word languages the app offers, so the API cannot claim to support a
// language the UI does not — `code` picks the definition edition, `section` the
// ==heading== to read on the English page.
const LANGUAGES = strings.wordLanguages;
const byCode = new Map(LANGUAGES.map(l => [l.code, l]));
const byName = new Map(LANGUAGES.map(l => [l.section.toLowerCase(), l]));

const MAX_WORD = 100;
const MAX_CHAIN = 10;

export class ToolError extends Error {}

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };

// No DOMParser in Workers. Strip repeatedly so `<<b>b>` cannot survive a single pass, then
// decode entities — order matters, or `&lt;script&gt;` would decode back into a tag.
export const strip = (s) => {
  // Wiktionary inlines a <style> block into the first definition of many pages; dropping
  // tags alone would leave the CSS itself sitting in the middle of the sentence.
  let out = String(s).replace(/<(style|script)\b[^>]*>[\s\S]*?<\/\1>/gi, '');
  for (let prev = null; prev !== out; ) { prev = out; out = out.replace(/<[^>]*>/g, ''); }
  return out
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&(\w+);/g, (m, n) => ENTITIES[n] ?? m)
    .replace(/\s+/g, ' ')
    .trim();
};

const escRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const word = (v) => {
  if (typeof v !== 'string' || !v.trim()) throw new ToolError('word is required');
  const w = v.trim();
  if (w.length > MAX_WORD) throw new ToolError(`word exceeds ${MAX_WORD} characters`);
  // A newline or a pipe would be a template-injection vector into the wikitext we parse.
  if (/[\n\r|{}]/.test(w)) throw new ToolError('word contains illegal characters');
  return w;
};

const wiki = (url) => fetch(url, { headers: { 'user-agent': UA } });

/** Body of the `==Name==` language section, or null. Stops at the next level-2 heading. */
const languageSection = (text, name) => {
  const m = new RegExp('^==\\s*' + escRe(name) + '\\s*==\\s*$', 'm').exec(text);
  if (!m) return null;
  const after = text.slice(m.index + m[0].length);
  const end = after.search(/^==[^=]/m);
  return end === -1 ? after : after.slice(0, end);
};

/** Definitions for one language section of one edition, or null if the page has none. */
async function definitions(w, language, edition) {
  const r = await wiki(`https://${edition}.wiktionary.org/api/rest_v1/page/definition/${encodeURIComponent(w)}`);
  if (!r.ok) return null;
  const d = await r.json();
  // Keyed by the language of each ==section==, so "chat" carries both `en` and `fr`.
  // The requested section is the answer; another language's is not a fallback, it is wrong.
  const entries = d[language];
  if (!entries?.length) return null;
  const groups = entries
    .map((e) => ({
      pos: e.partOfSpeech,
      definitions: (e.definitions || []).map((x) => strip(x.definition)).filter(Boolean).slice(0, 4),
    }))
    .filter((g) => g.definitions.length);
  return groups.length ? groups : null;
}

/** Ancestor chain from the English edition's etymology templates. Always `en`: only that
 *  edition uses inh/der/bor consistently across thousands of languages. */
async function etymology(w, section) {
  const r = await wiki(`${WIKI}/w/api.php?action=parse&page=${encodeURIComponent(w)}&prop=wikitext&format=json`);
  if (!r.ok) return [];
  const d = await r.json();
  const body = languageSection(d.parse?.wikitext?.['*'] || '', section);
  if (!body) return [];
  const m = body.match(/===?Etymology[^=]*===?\n([\s\S]*?)(\n===?[^=]|$)/);
  if (!m) return [];
  const chain = [];
  for (const x of m[1].matchAll(LINK_RE)) {
    const rel = REL[x[1].replace('+', '')];
    if (rel && x[3]) chain.push({ relation: rel, langCode: x[2], ancestor: x[3] });
    if (chain.length >= MAX_CHAIN) break;
  }
  return chain;
}

const wordArg = {
  type: 'object',
  properties: {
    word: { type: 'string', description: 'The word to look up.' },
    language: {
      type: 'string',
      description: 'Language of the word: a code ("la") or a section name ("Latin"). Default English.',
    },
  },
  required: ['word'],
};

export const LANGUAGE_LIST = LANGUAGES.map(l => ({ code: l.code, name: l.section }));

export const TOOLS = [
  {
    name: 'lookup_word',
    description: 'Definitions and etymology ancestors for a word, from Wiktionary.',
    inputSchema: wordArg,
  },
  {
    name: 'get_definitions',
    description: 'Just the definitions for a word, grouped by part of speech.',
    inputSchema: wordArg,
  },
  {
    name: 'list_languages',
    description: 'The word languages Wordroot supports, as codes and names.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_etymology',
    description: 'Just the etymology chain: inherited/derived/borrowed ancestors of a word.',
    inputSchema: wordArg,
  },
];

export const TOOL_NAMES = TOOLS.map((t) => t.name);

/** Accepts either a code (`la`) or a section name (`Latin`); anything else is a typo
 *  worth naming, not a silent fall back to English on the wrong word. */
const resolveLanguage = (v) => {
  if (v === undefined || v === null || v === '') return byCode.get('en');
  if (typeof v !== 'string') throw new ToolError('language must be a string');
  const hit = byCode.get(v.trim().toLowerCase()) || byName.get(v.trim().toLowerCase());
  if (!hit) throw new ToolError(`Unknown language: ${v}. Try a code like "la" or a name like "Latin".`);
  return hit;
};

export async function callTool(name, args = {}) {
  if (name === 'list_languages') return { languages: LANGUAGE_LIST };
  const w = word(args.word);
  const lang = resolveLanguage(args.language);
  const language = lang.section;

  switch (name) {
    case 'get_definitions':
      return { word: w, language, definitions: (await definitions(w, lang.code, 'en')) ?? [] };
    case 'get_etymology':
      return { word: w, language, etymology: await etymology(w, language) };
    case 'lookup_word': {
      const [defs, chain] = await Promise.all([
        definitions(w, lang.code, 'en'),
        etymology(w, language),
      ]);
      return {
        word: w,
        language,
        definitions: defs ?? [],
        etymology: chain,
        source: `${WIKI}/wiki/${encodeURIComponent(w)}`,
        license: 'CC BY-SA 4.0, Wiktionary',
      };
    }
    default:
      return null;
  }
}
