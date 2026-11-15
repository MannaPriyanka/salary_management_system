import { vi } from "vitest";

// Test helper: answers API calls from a route table keyed by "METHOD /path".
// Paths match exactly, with query strings ignored. Unknown routes fail the test.
export type Responder = (url: URL, init: RequestInit) => { status?: number; body?: unknown };

export function mockApi(routes: Record<string, Responder | { status?: number; body?: unknown }>) {
  const calls: { method: string; url: URL; body: unknown }[] = [];
  const fetchMock = vi.fn(async (input: string, init: RequestInit = {}) => {
    const url = new URL(input, "http://localhost");
    const method = (init.method ?? "GET").toUpperCase();
    const key = `${method} ${url.pathname.replace(/^\/api\/v1/, "")}`;
    const entry = routes[key];
    if (!entry) {
      throw new Error(`Unexpected API call: ${key}`);
    }
    calls.push({ method, url, body: init.body ? JSON.parse(String(init.body)) : undefined });
    const result = typeof entry === "function" ? entry(url, init) : entry;
    const status = result.status ?? 200;
    return new Response(status === 204 ? null : JSON.stringify(result.body ?? {}), { status });
  });
  vi.stubGlobal("fetch", fetchMock);
  return { calls, fetchMock };
}

export const notSignedIn = {
  status: 401,
  body: { error: { code: "not_signed_in", message: "Sign in is required." } },
};
