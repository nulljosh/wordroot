// WebMCP tool registration for Wordroot. Exposes read-only lookup tools to any
// agent that supports the WebMCP `document.modelContext` API, so an agent can
// look up words, pull etymology chains, or read the word of the day without
// scraping the page. All logic lives in the inline <script> in index.html —
// this file only wires window.* accessors from that script into tool calls.
//
// ponytail: no new fetch/parse logic here — every tool is a thin wrapper
// around functions the page already runs for its own UI.
(function () {
  const mc = document.modelContext;
  if (!mc?.registerTool) return;

  const tools = [
    {
      name: 'lookup_word',
      description: 'Look up a word in Wordroot: returns its definitions and etymology (ancestor chain), and also updates the on-page results so the user sees the same lookup.',
      inputSchema: {
        type: 'object',
        properties: {
          word: { type: 'string', description: 'The word to look up, e.g. "mother".' },
        },
        required: ['word'],
      },
      execute: async ({ word }) => {
        if (!word || !word.trim()) return { error: 'No word given.' };
        const w = word.trim().toLowerCase();
        const [defs, chain] = await Promise.all([
          window.wordrootDefinitions(w),
          window.wordrootEtymology(w),
        ]);
        if (!defs && !chain.length) return { error: `Nothing found for "${w}".` };
        window.wordrootLookup(w);
        return { word: w, definitions: defs || [], etymology: chain };
      },
    },
    {
      name: 'get_etymology',
      description: 'Get just the etymology (ancestor word chain, e.g. Old English, Proto-Germanic, Proto-Indo-European) for a word, without definitions.',
      inputSchema: {
        type: 'object',
        properties: {
          word: { type: 'string', description: 'The word to trace, e.g. "water".' },
        },
        required: ['word'],
      },
      execute: async ({ word }) => {
        if (!word || !word.trim()) return { error: 'No word given.' };
        const w = word.trim().toLowerCase();
        const chain = await window.wordrootEtymology(w);
        if (!chain.length) return { error: `No etymology found for "${w}".` };
        return { word: w, etymology: chain };
      },
    },
    {
      name: 'get_word_of_the_day',
      description: 'Get today\'s Wordroot word of the day (stable per calendar day, no arguments needed).',
      inputSchema: { type: 'object', properties: {} },
      execute: async () => ({ word: window.wordrootOfTheDay() }),
    },
  ];

  for (const tool of tools) {
    try {
      mc.registerTool(tool);
    } catch (err) {
      console.warn(`webmcp: failed to register tool "${tool.name}"`, err);
    }
  }
})();
