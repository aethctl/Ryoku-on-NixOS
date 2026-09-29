// The harness ledger: every installed coding agent, what it knows, where it
// keeps it. Backs the Agents panel from one /api/harnesses fetch shared with
// the Models panel (loadHarnesses caches, single in-flight). Credential rows
// are names only, because the daemon reports names only.

import { escapeHtml } from "./markdown.js";
import { humanBytes } from "./format.js";
import { api } from "./api.js";

export const harnessCache = { data: null, at: 0, promise: null };

const esc = (s) => escapeHtml(String(s == null ? "" : s));

// loadHarnesses shares one in-flight fetch between panels; 60s freshness
// matches the daemon TTL.
export function loadHarnesses() {
  const now = Date.now();
  if (harnessCache.data && now - harnessCache.at < 60_000) return Promise.resolve(harnessCache.data);
  if (!harnessCache.promise) {
    harnessCache.promise = api
      .harnesses()
      .then((d) => {
        harnessCache.data = d.harnesses || [];
        harnessCache.at = now;
        harnessCache.promise = null;
        return harnessCache.data;
      })
      .catch((err) => {
        harnessCache.promise = null;
        throw err;
      });
  }
  return harnessCache.promise;
}

function ago(iso) {
  if (!iso) return "";
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (!Number.isFinite(s) || s < 0) return "";
  if (s < 90) return "moments ago";
  if (s < 3600) return Math.round(s / 60) + " min ago";
  if (s < 86400) return Math.round(s / 3600) + " h ago";
  return Math.round(s / 86400) + " d ago";
}

export function renderLedger(root, rows) {
  if (!root) return;
  const present = (rows || []).filter((h) => h.present);
  if (!present.length) {
    root.innerHTML = '<p class="muted">No coding agents on this box yet.</p>';
    return;
  }
  root.innerHTML = present
    .map((h) => {
      const stats = [
        (h.skillCount || 0) + " skills",
        (h.sessions || 0) + " sessions",
        h.lastActive ? "active " + ago(h.lastActive) : "",
      ]
        .filter(Boolean)
        .join(" · ");
      const mem = (h.memories || [])
        .map(
          (m) =>
            '<span class="chip" title="' +
            esc(m.path) +
            '">' +
            esc(m.name) +
            (m.bytes ? " " + humanBytes(m.bytes) : m.entries ? " ×" + m.entries : "") +
            "</span>"
        )
        .join("");
      const creds = (h.creds || [])
        .map((c) => '<span class="chip dim">' + esc(c.kind === "env" ? "env:" : "file:") + esc(c.label) + "</span>")
        .join("");
      return (
        '<div class="card hcard">' +
        '<header><b>' + esc(h.name) + "</b>" +
        '<span class="dim">' + esc(h.version || "") + "</span>" +
        (h.wired ? '<span class="state ok">wired</span>' : '<span class="state idle">present</span>') +
        "</header>" +
        '<p class="hstats">' + esc(stats) + "</p>" +
        (h.model ? '<p class="hmodel"><span class="chip mono">' + esc(h.model) + "</span>" + (h.provider ? ' <span class="dim">' + esc(h.provider) + "</span>" : "") + "</p>" : "") +
        (mem ? '<div class="hchips">' + mem + "</div>" : "") +
        (creds ? '<div class="hchips">' + creds + "</div>" : "") +
        "</div>"
      );
    })
    .join("");
}

export function initLedger(container) {
  if (!container) return;
  loadHarnesses()
    .then((rows) => renderLedger(container, rows))
    .catch(() => {
      container.innerHTML = '<p class="muted">The daemon did not answer, so the ledger is empty.</p>';
    });
}
