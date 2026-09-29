// Vault panel: the machine's knowledge base as a grouped tree. Maps, memory,
// and journal are what a human reads; the source mirror (a full copy of
// ~/.config for the agent tools) is collapsed noise until asked for.

import { api } from "./api.js";
import { mdToHtml, escapeHtml } from "./markdown.js";
import { humanBytes } from "./format.js";

let current = null;
let tree = null;

export function initVault(root) {
  const listEl = root.querySelector("[data-vault-list]");
  const pane = root.querySelector("[data-vault-pane]");
  const reindexBtn = root.querySelector("[data-vault-reindex]");
  const head = root.querySelector(".vault-side-head");
  const openState = { maps: true, memory: true, journal: true, source: false, sourceExpanded: false };
  let journalAll = false;

  function groups(files) {
    // CLAUDE.md is a symlink to AGENTS.md: the same bytes twice is noise.
    const maps = files.filter(
      (f) => !f.path.includes("/") && f.path.endsWith(".md") && f.path !== "CLAUDE.md"
    );
    const memory = files.filter((f) => f.path.startsWith("memory/"));
    const journal = files
      .filter((f) => f.path.startsWith("journal/"))
      .sort((a, b) => new Date(b.mtime) - new Date(a.mtime));
    const source = files.filter((f) => f.path.startsWith("source/"));
    const other = files.filter(
      (f) => !maps.includes(f) && !memory.includes(f) && !journal.includes(f) && !source.includes(f)
    );
    return { maps, memory, journal, source, other };
  }

  function fileRow(f) {
    return (
      '<button class="vfile' + (current === f.path ? " active" : "") + '" data-p="' + escapeHtml(f.path) + '">' +
      '<span class="vfile-name">' + escapeHtml(f.path.split("/").pop()) + "</span>" +
      (f.generated ? '<span class="chip gen">gen</span>' : "") +
      '<span class="vfile-size">' + humanBytes(f.size) + "</span></button>"
    );
  }

  function renderList() {
    if (!tree) return;
    const g = groups(tree.files || []);
    const parts = [];

    const section = (key, label, files, opts) => {
      const o = opts || {};
      const open = openState[key];
      let rows = files;
      if (o.cap && !journalAll) rows = files.slice(0, o.cap);
      let html =
        '<div class="vgroup' + (open ? " open" : "") + '">' +
        '<button class="vgroup-head" type="button" data-g="' + key + '">' +
        "<span>" + label + '</span><span class="dim">' + files.length + "</span></button>";
      if (open) {
        html += '<div class="vgroup-items">' + rows.map(fileRow).join("");
        if (o.cap && files.length > o.cap) {
          html +=
            '<button class="btn btn-ghost vmore" type="button" data-more="1">' +
            (journalAll ? "show less" : "show all (" + files.length + ")") +
            "</button>";
        }
        if (o.more && files.length > 300) {
          html += '<p class="dim vmore-note">' + (files.length - 300) + " more</p>";
        }
        html += "</div>";
      }
      parts.push(html + "</div>");
    };

    section("maps", "Maps", g.maps);
    section("memory", "Memory", g.memory);
    section("journal", "Journal", g.journal, { cap: 8 });
    section("source", "Source mirror", g.source, { more: true });
    if (g.other.length) section("other", "Other", g.other);
    listEl.innerHTML = parts.join("");
  }

  async function open(rel) {
    current = rel;
    renderList();
    try {
      const md = await api.vaultFile(rel);
      pane.innerHTML = mdToHtml(md);
    } catch (err) {
      pane.innerHTML = '<p class="muted">Could not read ' + escapeHtml(rel) + "</p>";
    }
  }

  async function load() {
    try {
      tree = await api.vault();
    } catch (err) {
      listEl.innerHTML = '<p class="muted">The vault is out of reach.</p>';
      pane.innerHTML = '<p class="muted">Start the daemon to browse the vault.</p>';
      return;
    }
    const files = tree.files || [];
    if (!current || !files.some((f) => f.path === current)) {
      current = files.some((f) => f.path === "desktop.md")
        ? "desktop.md"
        : files.length
          ? files[0].path
          : null;
    }
    renderList();
    if (current) open(current);
  }

  listEl.addEventListener("click", (e) => {
    const more = e.target.closest("[data-more]");
    if (more) {
      journalAll = !journalAll;
      renderList();
      return;
    }
    const head = e.target.closest("[data-g]");
    if (head) {
      const key = head.dataset.g;
      openState[key] = !openState[key];
      renderList();
      return;
    }
    const f = e.target.closest(".vfile");
    if (f) open(f.dataset.p);
  });

  if (reindexBtn) {
    reindexBtn.addEventListener("click", async () => {
      reindexBtn.disabled = true;
      try {
        await api.reindex();
        await load();
        const ok = document.createElement("span");
        ok.className = "chip ok";
        ok.textContent = "reindexed";
        head.appendChild(ok);
        setTimeout(() => ok.remove(), 2000);
      } catch (err) {
        pane.innerHTML = '<p class="muted">Reindex failed.</p>';
      } finally {
        reindexBtn.disabled = false;
      }
    });
  }

  load();
}
