// Code intelligence card on the overview panel, fed by /api/prowl. The card
// starts hidden: it only unhides when prowl is installed. Indexed repos show
// doctor stamps + counts + hotspots; installed-but-unindexed shows an init hint;
// not installed (or any fetch failure) leaves the card hidden. Never throws,
// never console.errors: an absent daemon just leaves the card dark.

import { escapeHtml } from "./markdown.js";

async function getJSON(path) {
  const r = await fetch(path, { headers: { accept: "application/json" } });
  if (!r.ok) throw new Error(path + " -> " + r.status);
  return r.json();
}

function base(p) {
  const s = String(p || "");
  const parts = s.replace(/\/+$/, "").split("/");
  return parts[parts.length - 1] || s;
}

export function initCode(root) {
  const card = root.querySelector("[data-code-card]");
  const repoEl = root.querySelector("[data-code-repo]");
  const bodyEl = root.querySelector("[data-code-body]");
  if (!card) return;

  function renderIndexed(d) {
    const doc = d.doctor || {};
    const stamp = (cls, letter, n) =>
      '<span class="stamp ' + cls + '">' + letter + " " + (Number(n) || 0) + "</span>";
    const stamps =
      '<div class="code-stamps">' +
      stamp(doc.errors > 0 ? "stamp-vermillion" : "stamp-idle", "E", doc.errors) +
      stamp(doc.warns > 0 ? "stamp-warn" : "stamp-idle", "W", doc.warns) +
      stamp("stamp-idle", "I", doc.infos) +
      "</div>";
    const counts =
      '<div class="code-counts">' +
      (Number(d.files) || 0) +
      " files / " +
      (Number(d.symbols) || 0) +
      " symbols</div>";
    const spots = (d.hotspots || []).slice(0, 5);
    const hot = spots.length
      ? '<div class="code-hot">' +
        spots
          .map(
            (h) =>
              '<div class="code-hot-row"><span class="code-hot-file dim">' +
              escapeHtml(h.file || "") +
              '</span><span class="code-hot-in">' +
              (Number(h.in) || 0) +
              "</span></div>"
          )
          .join("") +
        "</div>"
      : "";
    bodyEl.innerHTML = stamps + counts + hot;
  }

  async function load() {
    let d;
    try {
      d = await getJSON("/api/prowl");
    } catch (err) {
      card.hidden = true;
      return;
    }
    if (!d || !d.installed) {
      card.hidden = true;
      return;
    }
    repoEl.textContent = base(d.repo);
    if (!d.indexed) {
      bodyEl.innerHTML =
        '<p class="dim">index missing: run <code>prowl init</code> in your repo</p>';
      card.hidden = false;
      return;
    }
    renderIndexed(d);
    card.hidden = false;
  }

  load();
}
