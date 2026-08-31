// One runnable check for the two things here that are actually logic: HTML stripping of
// publicly editable Wiktionary prose, and turning a wikitext etymology section into a chain.
// Wiktionary itself is stubbed — this tests the parsing, not the network.
import assert from 'node:assert/strict';

const real = globalThis.fetch;
globalThis.fetch = async (url) => {
  const u = String(url);
  if (u.includes('/page/definition/')) {
    return new Response(JSON.stringify({
      en: [{ partOfSpeech: 'Noun', definitions: [{ definition: '<style>.x{color:red}</style>A <b>test</b> &amp; more' }] }],
    }));
  }
  return new Response(JSON.stringify({
    parse: { wikitext: { '*': '==English==\n===Etymology===\nFrom {{inh|en|enm|water}}, from {{der|en|la|aqua}}.\n===Noun===\nx\n==French==\n' } },
  }));
};

const { callTool, strip, ToolError } = await import('../src/lib/tools.js');

assert.equal(strip('<style>.a{}</style>a <b>b</b> &amp; c'), 'a b & c');
// Nested angle brackets: what matters is that no tag survives, not the leftover text.
assert.ok(!strip('<<b>b>bold<scr<script>ipt>x').includes('<'));

const r = await callTool('lookup_word', { word: 'water' });
assert.equal(r.definitions[0].definitions[0], 'A test & more');
assert.deepEqual(r.etymology, [
  { relation: 'inherited', langCode: 'enm', ancestor: 'water' },
  { relation: 'derived', langCode: 'la', ancestor: 'aqua' },
]);

// A language section only exists on its own heading: French has no etymology on this page.
assert.deepEqual((await callTool('get_etymology', { word: 'water', language: 'fr' })).etymology, []);

await assert.rejects(() => callTool('lookup_word', { word: 'a|{{inh' }), ToolError);
await assert.rejects(() => callTool('lookup_word', { word: 'x', language: 'klingon' }), ToolError);
assert.equal(await callTool('nope', { word: 'x' }), null);

globalThis.fetch = real;
console.log('tools: ok');
