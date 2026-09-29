// The MODELS panel: every provider the agent stack can reach, in one table.
// The directory is Prowl's shipped catalogue (free / credits / paid tiers)
// served through rashin at /api/providers; "on this box" joins the harness
// credential names (names only) onto it. Nothing is scraped live and nothing
// is invented: an absent daemon leaves the panel honest about its source.

import { escapeHtml } from "./markdown.js";
import { api } from "./api.js";
import { loadHarnesses } from "./harnesses.js";

const esc = (s) => escapeHtml(String(s == null ? "" : s));

const CLASS_CHIP = { free: "ok", credits: "warn", paid: "info", oauth: "", local: "" };
const state = { all: [], harnesses: [], filter: "all", query: "" };

function onBox() {
  const set = new Set();
  for (const h of state.harnesses) {
    (h.creds || []).forEach((c) => set.add(c.label.toUpperCase()));
  }
  return set;
}

function match(p, keys) {
  const f = state.filter;
  if (f === "free" || f === "credits" || f === "paid") {
    if (p.class !== f) return false;
  } else if (f === "on") {
    if (!(p.env && keys.has(p.env.toUpperCase()))) return false;
  }
  if (state.query) {
    const hay = (p.name + " " + p.id + " " + (p.modalities || []).join(" ")).toLowerCase();
    if (!hay.includes(state.query)) return false;
  }
  return true;
}

function ctxLabel(n) {
  if (!n) return '<span class="dim">-</span>';
  if (n >= 1e6) return (n / 1e6).toFixed(n % 1e6 ? 1 : 0) + "M";
  return Math.round(n / 1000) + "k";
}

function render(root) {
  const keys = onBox();
  const list = root.querySelector("[data-models-list]");
  const filters = root.querySelector("[data-models-filters]");
  const byClass = (c) => state.all.filter((p) => p.class === c).length;
  const withKey = state.all.filter((p) => p.env && keys.has(p.env.toUpperCase())).length;

  filters.innerHTML = [
    ["all", "All", state.all.length],
    ["free", "Free", byClass("free")],
    ["credits", "Credits", byClass("credits")],
    ["paid", "Paid", byClass("paid")],
    ["on", "On this box", withKey],
  ]
    .map(
      ([k, label, n]) =>
        '<button class="seg-btn' + (state.filter === k ? " active" : "") + '" data-mfilter="' + k + '" type="button">' +
        label + " <b>" + n + "</b></button>"
    )
    .join("");

  const rows = state.all.filter((p) => match(p, keys));
  list.innerHTML = rows.length
    ? '<table class="data"><thead><tr><th>Provider</th><th>Class</th><th class="r">Free models</th><th class="r">Context</th><th>Signup</th><th>Routable</th><th>Key</th></tr></thead><tbody>' +
      rows
        .map((p) => {
          const here = p.env && keys.has(p.env.toUpperCase());
          return (
            "<tr>" +
            '<td><b>' + esc(p.name) + '</b> <span class="mono dim">' + esc(p.id) + "</span></td>" +
            '<td><span class="chip ' + (CLASS_CHIP[p.class] || "") + '">' + esc(p.class) + "</span></td>" +
            '<td class="r mono">' + (p.freeModels || 0) + "</td>" +
            '<td class="r mono">' + ctxLabel(p.maxContext) + "</td>" +
            '<td class="muted">' + esc(p.friction || "-") + "</td>" +
            "<td>" + (p.routable ? '<span class="state ok">yes</span>' : '<span class="state idle">no</span>') + "</td>" +
            "<td>" +
            (here ? '<span class="chip ok">on box</span> ' : "") +
            (p.apiKeyUrl
              ? '<a class="prov-key" href="' + esc(p.apiKeyUrl) + '" target="_blank" rel="noopener">get key ↗</a>'
              : '<span class="dim">-</span>') +
            "</td></tr>"
          );
        })
        .join("") +
      "</tbody></table>"
    : '<p class="empty">Nothing matches. Clear the filter or the search.</p>';

  filters.querySelectorAll("[data-mfilter]").forEach((b) =>
    b.addEventListener("click", () => {
      state.filter = b.dataset.mfilter;
      render(root);
    })
  );
}

export function initModels(root) {
  if (!root) return;
  const search = root.querySelector("[data-models-search]");
  if (search) {
    search.addEventListener("input", () => {
      state.query = search.value.trim().toLowerCase();
      if (state.all.length) render(root);
    });
  }
  Promise.all([api.providers().catch(() => []), loadHarnesses().catch(() => [])])
    .then(([providers, harnesses]) => {
      state.all = Array.isArray(providers) ? providers : [];
      state.harnesses = harnesses || [];
      if (!state.all.length) {
        root.querySelector("[data-models-list]").innerHTML =
          '<p class="muted">The provider directory comes from Prowl, and Prowl did not answer. Nothing here is made up, so the list stays empty.</p>';
        return;
      }
      render(root);
    })
    .catch(() => {
      root.querySelector("[data-models-list]").innerHTML = '<p class="muted">The daemon is not answering.</p>';
    });
}
