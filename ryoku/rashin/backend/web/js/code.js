// Code intelligence card: the number that matters is tokens the index saved
// this machine, not how many files it chewed through. Fed by /api/prowl (the
// daemon's cached report, which carries the measured savings) and stamped
// live/cached from /api/code/status when the Prowl API is reachable.

import { escapeHtml } from "./markdown.js";
import { api } from "./api.js";

function base(p) {
  const s = String(p || "");
  const parts = s.replace(/\/+$/, "").split("/");
  return parts[parts.length - 1] || s;
}

export function fmtTokens(n) {
  n = Number(n) || 0;
  if (n >= 1e9) return (n / 1e9).toFixed(n >= 1e10 ? 0 : 1) + "B";
  if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + "M";
  if (n >= 1e3) return (n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + "K";
  return String(n);
}

export function initCode(root) {
  const card = root.querySelector("[data-code-card]");
  const repoEl = root.querySelector("[data-code-repo]");
  const bodyEl = root.querySelector("[data-code-body]");
  if (!card) return;

  function render(d, serving) {
    const s = d.savings || {};
    const saved = Number(s.savedTokens) || 0;
    const queries = Number(s.queries) || 0;
    const answers = Number(s.answerTokens) || 0;

    const hero = saved
      ? '<div class="code-saved"><b>' +
        escapeHtml(fmtTokens(saved)) +
        "</b><span>tokens saved by indexed answers</span></div>"
      : '<div class="code-saved"><b>0</b><span>no measured savings yet; answers through prowl record themselves here</span></div>';

    const stats =
      '<div class="code-stats">' +
      '<div><b>' + queries + "</b><span>indexed answers</span></div>" +
      '<div><b>' + escapeHtml(fmtTokens(answers)) + "</b><span>answer tokens</span></div>" +
      '<div><b>' + (Number(d.files) || 0) + "</b><span>files</span></div>" +
      '<div><b>' + (Number(d.symbols) || 0) + "</b><span>symbols</span></div>" +
      "</div>";

    const doc = d.doctor || {};
    const chips =
      '<div class="code-chips">' +
      '<span class="chip ' + (doc.errors > 0 ? "bad" : "ok") + '">errors <b>' + (doc.errors || 0) + "</b></span>" +
      '<span class="chip ' + (doc.warns > 0 ? "warn" : "ok") + '">warnings <b>' + (doc.warns || 0) + "</b></span>" +
      '<span class="chip">' +
      (serving ? "live index" : "cached report") +
      "</span></div>";

    const spots = (d.hotspots || []).slice(0, 5);
    const hot = spots.length
      ? '<table class="data code-hot"><tbody>' +
        spots
          .map(
            (h) =>
              "<tr><td class=mono>" +
              escapeHtml(h.file || "") +
              '</td><td class="r mono">' +
              (Number(h.in) || 0) +
              "</td></tr>"
          )
          .join("") +
        "</tbody></table>"
      : "";

    bodyEl.innerHTML = hero + stats + chips + hot;
    repoEl.textContent = base(d.repo) + (serving ? " · live" : "");
    card.hidden = false;
  }

  async function load() {
    let serving = false;
    try {
      const st = await api.codeStatus();
      if (!st || !st.installed) {
        card.hidden = true;
        return;
      }
      serving = !!st.serving;
    } catch (err) {
      /* pre-api daemons: fall through to the cached report */
    }
    try {
      const d = await getJSON("/api/prowl");
      if (!d || !d.installed) {
        card.hidden = true;
        return;
      }
      if (!d.indexed) {
        repoEl.textContent = base(d.repo);
        bodyEl.innerHTML = '<p class="muted">No index yet. Run <code class=mono>prowl init</code> in your repo.</p>';
        card.hidden = false;
        return;
      }
      render(d, serving);
    } catch (err) {
      card.hidden = true;
    }
  }

  async function getJSON(path) {
    const r = await fetch(path, { headers: { accept: "application/json" } });
    if (!r.ok) throw new Error(path + " -> " + r.status);
    return r.json();
  }

  load();
}
