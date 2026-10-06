// The daemon's HTTP contract (ryoku/rashin/backend/server.go), one function
// per route. Every call resolves to data or throws an ApiError; a page shows
// its empty or offline state on throw, so an absent daemon degrades instead
// of crashing the console.

export class ApiError extends Error {
  status: number;
  constructor(path: string, status: number, detail?: string) {
    super(detail || `${path} answered ${status}`);
    this.status = status;
  }
}

async function getJSON<T>(path: string): Promise<T> {
  const r = await fetch(path, { headers: { accept: "application/json" } });
  if (!r.ok) throw new ApiError(path, r.status);
  return (await r.json()) as T;
}

async function postJSON<T>(path: string, body?: unknown): Promise<T> {
  const r = await fetch(path, {
    method: "POST",
    headers: body === undefined ? {} : { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const parsed = (await r.json().catch(() => ({}))) as { error?: string } & T;
  if (!r.ok) throw new ApiError(path, r.status, parsed.error);
  return parsed;
}

export type Json = Record<string, unknown>;

export const api = {
  ping: async (): Promise<boolean> => {
    try {
      const r = await fetch("/api/ping", { cache: "no-store" });
      return r.ok;
    } catch {
      return false;
    }
  },
  status: () => getJSON<Json>("/api/status"),
  vitals: () => getJSON<Json>("/api/vitals"),
  system: () => getJSON<Json>("/api/system"),
  doctor: (refresh = false) => getJSON<Json>("/api/doctor" + (refresh ? "?refresh=1" : "")),
  fix: (req: Json) => postJSON<Json>("/api/fix", req),
  theme: () => getJSON<Json>("/api/theme"),
  wallpaper: () => getJSON<Json>("/api/wallpaper"),
  vault: () => getJSON<Json>("/api/vault"),
  vaultFile: async (rel: string): Promise<string> => {
    const path = "/api/vault/file?p=" + encodeURIComponent(rel);
    const r = await fetch(path);
    if (!r.ok) throw new ApiError(path, r.status);
    return r.text();
  },
  reindex: () => postJSON<Json>("/api/index"),
  agents: () => getJSON<Json>("/api/agents"),
  harnesses: () => getJSON<Json>("/api/harnesses"),
  wire: (id: string) => postJSON<Json>("/api/agents/wire", { id }),
  unwire: (id: string) => postJSON<Json>("/api/agents/unwire", { id }),
  quick: () => getJSON<Json>("/api/quick"),
  setQuick: (provider: string) => postJSON<Json>("/api/quick?provider=" + encodeURIComponent(provider)),
  manifest: () => getJSON<Json>("/api/manifest"),
  chatAgents: () => getJSON<Json>("/api/chat/agent"),
  setChatAgent: (id: string) => postJSON<Json>("/api/chat/agent?id=" + encodeURIComponent(id)),
  hermesSkills: () => getJSON<Json>("/api/hermes/skills"),
  hermesMemory: () => getJSON<Json>("/api/hermes/memory"),
  prowl: () => getJSON<Json>("/api/prowl"),
  prowlSearch: (q: string) => getJSON<Json>("/api/prowl/search?q=" + encodeURIComponent(q)),
  codeStatus: () => getJSON<Json>("/api/code/status"),
  code: (endpoint: string, params?: Record<string, string>) =>
    getJSON<Json>("/api/code/" + endpoint + (params ? "?" + new URLSearchParams(params).toString() : "")),
  providers: () => getJSON<Json>("/api/providers"),
  about: () => getJSON<Json>("/api/about"),
  /** the quick lane: a chunked text/plain stream of @working/@perm/@answer/@error lines */
  ask: async (q: string): Promise<Response> => {
    const path = "/api/ask?q=" + encodeURIComponent(q);
    const r = await fetch(path, { method: "POST", headers: { accept: "text/plain" } });
    if (!r.ok) throw new ApiError(path, r.status, await r.text().catch(() => ""));
    return r;
  },
  askRecent: () => getJSON<Json>("/api/ask/recent"),
  askCancel: () => postJSON<Json>("/api/ask/cancel"),
};

export function wsUrl(path: string): string {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return proto + "//" + location.host + path;
}
