// Agents panel: one card per detected coding agent with wire/unwire, the
// "point any agent" manifest (paths Rashin exposes plus a copyable instruction
// block), the chat-backend picker, and the harness ledger fed by the shared
// /api/harnesses scan. All best effort: an absent daemon degrades to muted
// placeholders.

import { api } from "./api.js";
import { escapeHtml } from "./markdown.js";
import { initLedger } from "./harnesses.js";

const esc = (s) => escapeHtml(String(s == null ? "" : s));

export function initAgents(root) {
  const listEl = root.querySelector("[data-agents-list]");
  const connectEl = root.querySelector("[data-connect]");
  const chatEl = root.querySelector("[data-chatbackend]");
  let snippet = "";

  function card(a) {
    const state = a.wired
      ? '<span class="state ok">wired</span>'
      : a.present
        ? '<span class="state idle">present</span>'
        : '<span class="state bad">absent</span>';
    const skill = a.skillWired ? '<span class="chip info">skill</span>' : "";
    const action = a.wired
      ? '<button class="btn btn-ghost" data-act="unwire" data-id="' + esc(a.id) + '">Unwire</button>'
      : '<button class="btn btn-primary" data-act="wire" data-id="' + esc(a.id) + '"' +
        (a.present ? "" : " disabled") + ">Wire</button>";
    return (
      '<div class="card acard" data-id="' + esc(a.id) + '">' +
      '<div class="acard-head"><b>' + esc(a.name) + "</b>" + skill + state + "</div>" +
      '<span class="mono dim acard-file">' + esc(a.file || "") + "</span>" +
      '<div class="acard-act">' + action + "</div></div>"
    );
  }

  function pathRow(label, path, owner, ok) {
    return (
      '<div class="mrow' + (ok ? "" : " absent") + '">' +
      '<span class="mlabel">' + esc(label) + "</span>" +
      '<span class="chip">' + esc(owner || "") + "</span>" +
      '<span class="mpath">' + esc(path || "not installed") + "</span>" +
      (ok ? "" : '<span class="state bad">missing</span>') +
      "</div>"
    );
  }

  function renderConnect(m) {
    snippet = m.snippet || "";
    const rows = [
      pathRow("skill", m.skill && m.skill.path, "read-only", m.skill && m.skill.exists),
      pathRow("prowl", m.prowl && m.prowl.path, "tool", m.prowl && m.prowl.exists),
    ].concat((m.vault || []).map((v) => pathRow(v.label, v.path, v.owner, v.exists)));
    connectEl.innerHTML =
      '<div class="card-head"><h2>Point any agent</h2><span class="card-meta">paths Rashin exposes</span></div>' +
      rows.join("") +
      '<button class="btn btn-primary manifest-copy" data-act="copy">Copy agent snippet</button>';
  }

  function renderChat(backs) {
    const btns = (backs || [])
      .map((b) => {
        const cls = "seg-btn" + (b.active ? " active" : "");
        const star = b.recommended ? ' <i class="seg-tag">recommended</i>' : "";
        const dis = b.available ? "" : " disabled";
        return '<button class="' + cls + '" data-chat="' + esc(b.id) + '"' + dis + ">" + esc(b.name) + star + "</button>";
      })
      .join("");
    chatEl.innerHTML =
      '<div class="card-head"><h2>Chat backend</h2><span class="card-meta">who answers the chat</span></div>' +
      '<div class="seg chip-row">' + btns + "</div>";
  }

  async function load() {
    try {
      const list = await api.agents();
      listEl.innerHTML = (list || []).map(card).join("");
    } catch (err) {
      listEl.innerHTML = '<p class="muted">The daemon is not running, so there are no agents to show.</p>';
    }
    try { renderConnect(await api.manifest()); } catch (e) { connectEl.innerHTML = ""; }
    try { renderChat(await api.chatAgents()); } catch (e) { chatEl.innerHTML = ""; }
  }

  listEl.addEventListener("click", async (e) => {
    const btn = e.target.closest("[data-act]");
    if (!btn || btn.disabled) return;
    btn.disabled = true;
    try {
      await (btn.dataset.act === "wire" ? api.wire(btn.dataset.id) : api.unwire(btn.dataset.id));
    } catch (err) { /* reload reflects real state */ }
    await load();
  });

  connectEl.addEventListener("click", async (e) => {
    const btn = e.target.closest('[data-act="copy"]');
    if (!btn) return;
    try {
      await navigator.clipboard.writeText(snippet);
      btn.textContent = "Copied";
      setTimeout(() => { btn.textContent = "Copy agent snippet"; }, 1500);
    } catch (err) { /* clipboard blocked; the paths above still stand */ }
  });

  chatEl.addEventListener("click", async (e) => {
    const btn = e.target.closest("[data-chat]");
    if (!btn || btn.disabled) return;
    try { await api.setChatAgent(btn.dataset.chat); } catch (err) {}
    await load();
  });

  load();
  initLedger(root.querySelector("[data-harness-ledger]"));
}
