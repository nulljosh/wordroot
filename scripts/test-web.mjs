// Tests the web app's real shipping code: web/i18n.js is loaded as-is, and the inline
// <script> from web/index.html is evaluated against a stub DOM and a fake Wiktionary.
// Run: node scripts/test-web.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const tests = [];
const test = (name, fn) => tests.push([name, fn]);

// Values built inside the vm realm carry that realm's prototypes, which strict deepEqual
// compares by identity. Round-tripping through JSON compares what we actually care about.
const same = (actual, expected, msg) =>
  assert.deepEqual(JSON.parse(JSON.stringify(actual)), expected, msg);

// --- stub DOM -------------------------------------------------------------------------
function makeElement(tag = 'div') {
  const el = {
    tagName: tag, children: [], style: {}, attributes: {}, value: '',
    innerHTML: '', textContent: '', className: '', placeholder: '', selected: false,
    setAttribute(k, v) { this.attributes[k] = v; },
    getAttribute(k) { return this.attributes[k]; },
    addEventListener(type, fn) { (this.listeners ||= {})[type] = fn; },
    appendChild(c) { this.children.push(c); return c; },
    append(...cs) { this.children.push(...cs); },
  };
  return el;
}

function makeContext({ lang = 'en', search = '', store = {}, fetch: fetchImpl, bundle = 'web/i18n.js' } = {}) {
  const byId = {};
  for (const id of ['q', 'wotd', 'out', 'attr', 'uiPicker', 'wordPicker']) byId[id] = makeElement();
  const documentElement = makeElement('html');
  const ctx = {
    console, setTimeout, clearTimeout, URL, URLSearchParams, Intl, JSON, Date, Object, Math,
    Promise, RegExp, String, Array, Error,
    location: { search, href: 'https://wordroot.test/' + search, replace() {} },
    navigator: { languages: [lang], language: lang },
    localStorage: {
      getItem: k => (k in store ? store[k] : null),
      setItem: (k, v) => { store[k] = v; },
    },
    document: {
      documentElement,
      getElementById: id => byId[id] || null,
      createElement: makeElement,
      set title(v) { this._title = v; },
      get title() { return this._title; },
    },
    DOMParser: class { parseFromString(s) { return { body: { textContent: s.replace(/<[^>]*>/g, '') } } } },
    fetch: fetchImpl || (async () => ({ ok: false })),
  };
  ctx.__elements = byId;  // so tests can read what was rendered
  ctx.window = ctx;
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(readFileSync(join(ROOT, bundle), 'utf8'), ctx, { filename: bundle });
  return ctx;
}

function runPage(opts) {
  const ctx = makeContext(opts);
  const html = readFileSync(join(ROOT, 'web/index.html'), 'utf8');
  const inline = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)]
    .map(m => m[1]).join('\n');
  vm.runInContext(inline, ctx, { filename: 'index.html' });
  return ctx;
}

// --- fixtures -------------------------------------------------------------------------
// "chat" is the case that matters: one page, an English section and a French one, each with
// its own etymology. Picking the wrong section silently returns another language's history.
const CHAT_WIKITEXT = `==English==

===Etymology===
From {{inh|en|enm|chat}}, from {{der|en|ang|ceatian}}.

===Noun===

==French==

===Etymology===
From {{inh|fr|fro|chat}}, from {{inh|fro|la|cattus}}, from {{der|fr|la-med|catta}}.

===Noun===
`;

// `definitions` maps a Wiktionary edition host prefix to what that edition serves; a value of
// a number is an HTTP status instead, for editions that answer but not with definitions.
const wiktionary = (wikitext, definitions = {}) => {
  const calls = [];
  const impl = async url => {
    if (url.includes('/page/definition/')) {
      const edition = url.match(/https:\/\/([^.]+)\.wiktionary/)[1];
      calls.push(edition);
      const served = definitions[edition];
      if (served === undefined) return { ok: false, status: 404 };
      if (typeof served === 'number') return { ok: false, status: served };
      return { ok: true, json: async () => served };
    }
    return { ok: true, json: async () => ({ parse: { wikitext: { '*': wikitext } } }) };
  };
  impl.calls = calls;
  return impl;
};

const NOUN = text => [{ partOfSpeech: 'Noun', definitions: [{ definition: text }] }];

// --- i18n runtime ---------------------------------------------------------------------
test('negotiates an exact locale from the browser', () => {
  assert.equal(makeContext({ lang: 'fr' }).i18n.locale, 'fr');
});

test('negotiates a regional tag down to its base language', () => {
  assert.equal(makeContext({ lang: 'pt-BR' }).i18n.locale, 'pt');
});

test('routes every Chinese variant to Simplified', () => {
  for (const tag of ['zh', 'zh-CN', 'zh-Hant-TW', 'zh-Hans']) {
    assert.equal(makeContext({ lang: tag }).i18n.locale, 'zh-Hans', tag);
  }
});

test('falls back to English for a locale we do not ship', () => {
  assert.equal(makeContext({ lang: 'sw-KE' }).i18n.locale, 'en');
});

test('?lang= overrides the browser, and the stored choice overrides ?lang=', () => {
  assert.equal(makeContext({ lang: 'de', search: '?lang=ja' }).i18n.locale, 'ja');
  const stored = makeContext({ lang: 'de', search: '?lang=ja', store: { 'wordroot.uiLang': 'ko' } });
  assert.equal(stored.i18n.locale, 'ja', '?lang= is checked before storage');
});

test('marks Arabic right-to-left and everything else left-to-right', () => {
  assert.equal(makeContext({ lang: 'ar' }).i18n.dir, 'rtl');
  assert.equal(makeContext({ lang: 'he' }).i18n.dir, 'ltr', 'he is not a shipped locale');
  assert.equal(makeContext({ lang: 'ja' }).i18n.dir, 'ltr');
});

test('applyDocumentLanguage stamps lang and dir on <html>', () => {
  const ctx = makeContext({ lang: 'ar' });
  ctx.i18n.applyDocumentLanguage();
  assert.equal(ctx.document.documentElement.lang, 'ar');
  assert.equal(ctx.document.documentElement.dir, 'rtl');
});

test('interpolates placeholders and leaves unknown ones alone', () => {
  const { i18n } = makeContext({ lang: 'fr' });
  assert.equal(i18n.t('ui.nothingFoundFor', { word: 'chat' }), 'Aucun résultat pour « chat ».');
  assert.equal(i18n.t('ui.nothingFoundFor', {}), 'Aucun résultat pour « {word} ».');
});

test('falls back to English for a key with no translation, and to the key itself if unknown', () => {
  const { i18n } = makeContext({ lang: 'ja' });
  assert.equal(i18n.t('nope.not.a.key'), 'nope.not.a.key');
});

test('localizes ancestor language names, hand translations winning over CLDR', () => {
  const de = makeContext({ lang: 'de' }).i18n;
  assert.equal(de.languageName('ine-pro'), 'Urindogermanisch', 'hand-translated proto-language');
  assert.equal(de.languageName('la'), 'Latein', 'from CLDR');
  const en = makeContext({ lang: 'en' }).i18n;
  assert.equal(en.languageName('NL.'), 'New Latin', 'not a valid BCP 47 tag; must not throw');
  assert.equal(en.languageName('xyz'), 'xyz', 'unknown code renders as itself');
});

// --- lookup ---------------------------------------------------------------------------
test('reads the etymology of the selected word language, not the first on the page', async () => {
  const ctx = runPage({ lang: 'en', fetch: wiktionary(CHAT_WIKITEXT) });
  const en = await ctx.wordrootEtymology('chat', 'en');
  same(en.map(c => c.ancestor), ['chat', 'ceatian']);
  const fr = await ctx.wordrootEtymology('chat', 'fr');
  same(fr.map(c => c.ancestor), ['chat', 'cattus', 'catta']);
});

test('returns no etymology when the page has no section in that language', async () => {
  const ctx = runPage({ lang: 'en', fetch: wiktionary(CHAT_WIKITEXT) });
  same(await ctx.wordrootEtymology('chat', 'ja'), []);
});

test('stops at the next language section rather than running into it', async () => {
  const ctx = runPage({ lang: 'en', fetch: wiktionary(CHAT_WIKITEXT) });
  const en = await ctx.wordrootEtymology('chat', 'en');
  assert.ok(!en.some(c => c.ancestor === 'cattus'), 'French ancestry leaked into English');
});

test('localizes the relation and ancestor language of each link', async () => {
  const ctx = runPage({ lang: 'de', fetch: wiktionary(CHAT_WIKITEXT) });
  const [first] = await ctx.wordrootEtymology('chat', 'fr');
  assert.equal(first.rel, 'ererbt');
  assert.equal(first.lang, 'Altfranzösisch');
  assert.equal(first.langCode, 'fro', 'raw code kept for the lang attribute');
});

test('returns only the definitions of the selected word language', async () => {
  const en = { en: NOUN('Informal talk.'), fr: NOUN('<i>cat</i>') };
  const ctx = runPage({ lang: 'en', fetch: wiktionary(CHAT_WIKITEXT, { en }) });
  same(await ctx.wordrootDefinitions('chat', 'fr'), { edition: 'en', groups: [{ pos: 'Noun', defs: ['cat'] }] });
  assert.equal(await ctx.wordrootDefinitions('chat', 'de'), null, 'no German section is a miss');
});

test('prefers the reader’s own Wiktionary edition, so the glosses are in their language', async () => {
  const fetch = wiktionary(CHAT_WIKITEXT, {
    fr: { fr: NOUN('Animal domestique.') },
    en: { fr: NOUN('A domestic cat.') },
  });
  const ctx = runPage({ lang: 'fr', fetch });
  const defs = await ctx.wordrootDefinitions('chat', 'fr');
  assert.equal(defs.edition, 'fr');
  same(defs.groups, [{ pos: 'Noun', defs: ['Animal domestique.'] }]);
});

test('falls back to English when the reader’s edition lacks the word', async () => {
  const fetch = wiktionary(CHAT_WIKITEXT, { en: { fr: NOUN('A domestic cat.') } });  // fr 404s
  const ctx = runPage({ lang: 'fr', fetch });
  const defs = await ctx.wordrootDefinitions('chat', 'fr');
  assert.equal(defs.edition, 'en', 'a 404 from fr must not lose the English definitions');
  same(defs.groups, [{ pos: 'Noun', defs: ['A domestic cat.'] }]);
});

test('an English interface asks only the English edition', async () => {
  const fetch = wiktionary(CHAT_WIKITEXT, { en: { en: NOUN('Informal talk.') } });
  const ctx = runPage({ lang: 'en', fetch, store: { 'wordroot.wordLang': 'cy' } });
  await ctx.wordrootDefinitions('chat', 'en');
  same(fetch.calls, ['en'], 'no second edition to try');
});

test('stops asking an edition that does not serve definitions at all', async () => {
  // 501 rather than 404: the endpoint is absent here, not the word.
  const fetch = wiktionary(CHAT_WIKITEXT, { ja: 501, en: { ja: NOUN('Cat.') } });
  const ctx = runPage({ lang: 'ja', fetch, store: { 'wordroot.wordLang': 'cy' } });
  const first = await ctx.wordrootDefinitions('chat', 'ja');
  assert.equal(first.edition, 'en');
  same(fetch.calls, ['ja', 'en'], 'both probed the first time');
  await ctx.wordrootDefinitions('chat', 'ja');
  same(fetch.calls, ['ja', 'en', 'en'], 'ja must not be probed a second time');
});

test('a throwing edition is retired rather than failing the lookup', async () => {
  const base = wiktionary(CHAT_WIKITEXT, { en: { fr: NOUN('A domestic cat.') } });
  const fetch = async url => {
    if (url.startsWith('https://fr.')) throw new Error('DNS');
    return base(url);
  };
  const ctx = runPage({ lang: 'fr', fetch });
  assert.equal((await ctx.wordrootDefinitions('chat', 'fr')).edition, 'en');
});

test('defaults the word language to the interface language when a dictionary exists', () => {
  assert.equal(runPage({ lang: 'fr', fetch: wiktionary('') }).wordrootWordLanguage(), 'fr');
  assert.equal(runPage({ lang: 'zh-Hans', fetch: wiktionary('') }).wordrootWordLanguage(), 'zh',
    'zh-Hans interface maps onto the zh dictionary');
});

test('word of the day is stable per day and drawn from the word language', () => {
  const ctx = runPage({ lang: 'ru', fetch: wiktionary('') });
  const word = ctx.wordrootOfTheDay();
  assert.equal(ctx.wordrootOfTheDay(), word, 'not stable within a day');
  assert.ok(/^[Ѐ-ӿ]+$/.test(word), `expected a Russian word, got ${word}`);
});

test('word of the day is absent for a language we ship no list for', () => {
  const ctx = runPage({ lang: 'en', store: { 'wordroot.wordLang': 'cy' }, fetch: wiktionary('') });
  assert.equal(ctx.wordrootWordLanguage(), 'cy');
  assert.equal(ctx.wordrootOfTheDay(), null);
});

test('says so when the reader gets English prose, and links to their own Wiktionary', async () => {
  const fetch = wiktionary(CHAT_WIKITEXT, { en: { fr: NOUN('A domestic cat.') } });  // fr 404s
  const ctx = runPage({ lang: 'fr', fetch });
  await ctx.wordrootLookup('chat');
  const html = ctx.__elements.out.innerHTML;
  assert.ok(html.includes('Ces définitions sont en anglais.'), 'no notice rendered');
  assert.ok(html.includes('https://fr.wiktionary.org/wiki/chat'), 'no link to the fr edition');
  assert.ok(html.includes('Ouvrir sur le Wiktionnaire'), 'link label not localized');
});

test('stays quiet when the reader’s own edition supplied the definitions', async () => {
  const fetch = wiktionary(CHAT_WIKITEXT, {
    fr: { fr: NOUN('Animal domestique.') },
    en: { fr: NOUN('A domestic cat.') },
  });
  const ctx = runPage({ lang: 'fr', fetch });
  await ctx.wordrootLookup('chat');
  const html = ctx.__elements.out.innerHTML;
  assert.ok(html.includes('Animal domestique.'), 'French gloss not shown');
  assert.ok(!html.includes('en anglais'), 'notice shown when it should not be');
});

test('never shows the notice to an English reader', async () => {
  const fetch = wiktionary(CHAT_WIKITEXT, { en: { en: NOUN('Informal talk.') } });
  const ctx = runPage({ lang: 'en', fetch });
  await ctx.wordrootLookup('chat');
  assert.ok(!ctx.__elements.out.innerHTML.includes('are in English'));
});

// --- landing bundle -------------------------------------------------------------------
const landing = opts => makeContext({ ...opts, bundle: 'landing/i18n.js' }).i18n;

test('hero wall keeps the headword and source form, translating only the meaning', () => {
  const salary = c => landing({ lang: c }).wall.filter(e => e.word === 'salary')[0];
  assert.equal(salary('en').form, 'salarium');
  assert.equal(salary('en').meaning, 'salt money');
  assert.equal(salary('de').form, 'salarium', 'the Latin source form must not be translated');
  assert.equal(salary('de').meaning, 'Salzgeld');
  assert.equal(salary('ar').meaning, 'مال الملح');
});

test('every hero wall entry has a meaning in every shipped locale', () => {
  for (const { code } of landing().locales) {
    for (const entry of landing({ lang: code }).wall) {
      assert.ok(entry.meaning, `${entry.word} has no meaning in ${code}`);
    }
  }
});

test('the landing bundle ships no dictionary tables it never renders', () => {
  const l = landing();
  same(l.wordLanguages, []);
  same(l.wordsOfTheDay, {});
  assert.ok(landing().locales.length > 0, 'but it does ship the locale list for its picker');
});

test('the web bundle ships no hero wall it never renders', () => {
  same(makeContext().i18n.wall, []);
});

// --- run ------------------------------------------------------------------------------
let failed = 0;
for (const [name, fn] of tests) {
  try {
    await fn();
    console.log(`ok   ${name}`);
  } catch (err) {
    failed++;
    console.log(`FAIL ${name}\n     ${err.message.split('\n').join('\n     ')}`);
  }
}
console.log(`\n${tests.length - failed}/${tests.length} passed`);
process.exit(failed ? 1 : 0);
