// REST surface. Thin: every route shuffles arguments into callTool() in src/lib/tools.js,
// which functions/mcp.js also calls. No Wiktionary parsing lives here.

import { callTool, ToolError, TOOL_NAMES } from '../../src/lib/tools.js';

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'content-type',
  'access-control-allow-methods': 'GET, OPTIONS',
};

const json = (body, status = 200) =>
  new Response(JSON.stringify(body, null, 2), {
    status,
    // Wiktionary content does not change minute to minute, and an agent hammering one
    // word should not become an equal number of upstream requests.
    headers: { 'content-type': 'application/json', 'cache-control': 'public, max-age=3600', ...CORS },
  });

const ENDPOINTS = {
  'GET /api/languages': 'The supported word languages.',
  'GET /api/word/:word?lang=': 'Definitions + etymology.',
  'GET /api/definitions/:word?lang=': 'Definitions only.',
  'GET /api/etymology/:word?lang=': 'Etymology chain only.',
  'POST /mcp': 'Model Context Protocol, JSON-RPC. Same tools.',
};

const ROUTES = {
  word: 'lookup_word',
  definitions: 'get_definitions',
  etymology: 'get_etymology',
};

export async function onRequest({ request }) {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (request.method !== 'GET') return json({ error: 'This API is read-only; use GET.' }, 405);

  const url = new URL(request.url);
  const parts = url.pathname.replace(/\/+$/, '').split('/').filter(Boolean); // ['api', ...]

  if (parts.length === 1) return json({ endpoints: ENDPOINTS, tools: TOOL_NAMES });
  if (parts[1] === 'languages') return json(await callTool('list_languages'));

  const tool = ROUTES[parts[1]];
  // decodeURIComponent throws on a malformed escape like `%zz`, which is the caller's typo.
  let word;
  try {
    word = parts[2] === undefined ? undefined : decodeURIComponent(parts[2]);
  } catch {
    return json({ error: 'Malformed percent-encoding in the word.' }, 400);
  }
  if (!tool) return json({ error: `Unknown endpoint: GET ${url.pathname}`, endpoints: ENDPOINTS }, 404);

  try {
    return json(await callTool(tool, { word, language: url.searchParams.get('lang') ?? undefined }));
  } catch (err) {
    if (err instanceof ToolError) return json({ error: err.message }, 400);
    // Wiktionary being down is not the caller's fault, and should not read like their bug.
    return json({ error: 'Upstream Wiktionary request failed.' }, 502);
  }
}
