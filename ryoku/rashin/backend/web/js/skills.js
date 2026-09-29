// Skills panel: one tab per installed harness. Hermes (the resident agent)
// groups its skills by category with origin counts and the enabled toolbelt;
// every other harness lists the skills it actually carries. filterCategories
// is a pure node-tested helper.

import { escapeHtml } from "./markdown.js";
import { api } from "./api.js";

// filterCategories(categories, query) -> categories with only matching skills,
// dropping groups that end up empty. Case-insensitive substring over skill name
// + description. Empty/blank query returns every category unchanged.
export function filterCategories(categories, query) {
  const cats = Array.isArray(categories) ? categories : [];
  const q = String(query == null ? "" : query).trim().toLowerCase();
  if (!q) return cats.slice();
  const out = [];
  for (const c of cats) {
    const skills = (c.skills || []).filter((s) => {
      const hay = ((s.name || "") + " " + (s.description || "")).toLowerCase();
      return hay.indexOf(q) !== -1;
    });
    if (skills.length) out.push({ name: c.name, skills });
  }
  return out;
}

const esc = (s) => escapeHtml(String(s == null ? "" : s));

const ORIGIN_CHIP = { bundled: "ok", hub: "ok", shipped: "info", managed: "info", agent: "", plugin: "" };

// groupByOrigin turns a flat skill list into origin groups so a 200-skill
// harness stays scannable.
export function groupByOrigin(skills) {
  const by = {};
  for (const s of skills || []) (by[s.origin || "agent"] = by[s.origin || "agent"] || []).push(s);
  return Object.keys(by)
    .sort()
    .map((name) => ({ name, skills: by[name] }));
}

export function initSkills(root) {
  const tabsEl = root.querySelector("[data-skills-tabs]");
  const countsEl = root.querySelector("[data-skills-counts]");
  const groupsEl = root.querySelector("[data-skills-groups]");
  const searchEl = root.querySelector("[data-skills-search]");
  const beltWrap = root.querySelector(".toolbelt-wrap");
  const beltEl = root.querySelector("[data-toolbelt]");

  let hermes = null; // {counts, categories, toolbelt}
  let harnesses = null; // [{id,name,skillCount,skills}]
  let active = "hermes";
  let query = "";
  const open = new Set();
  let touched = false;

  function dataset() {
    if (active === "hermes") return hermes ? hermes.categories : [];
    const h = (harnesses || []).find((x) => x.id === active);
    if (!h) return [];
    const skills = h.skills || [];
    return skills.length > 25 ? groupByOrigin(skills) : [{ name: "Skills", skills }];
  }

  function renderTabs() {
    const tabs = [{ id: "hermes", name: "Hermes", n: hermes ? hermes.categories.reduce((a, c) => a + (c.skills || []).length, 0) : 0 }];
    for (const h of harnesses || []) {
      if (h.id !== "hermes" && h.present && (h.skillCount || 0) > 0) tabs.push({ id: h.id, name: h.name, n: h.skillCount });
    }
    tabsEl.innerHTML = tabs
      .map(
        (t) =>
          '<button class="seg-btn' + (active === t.id ? " active" : "") + '" data-h="' + esc(t.id) + '" type="button">' +
          esc(t.name) + " <b>" + t.n + "</b></button>"
      )
      .join("");
  }

  function renderCounts(cats) {
    const all = cats.flatMap((c) => c.skills || []);
    const total = active === "hermes" && hermes ? Object.values(hermes.counts || {}).reduce((a, b) => a + b, 0) : all.length;
    const by = {};
    for (const s of all) by[s.origin || "agent"] = (by[s.origin || "agent"] || 0) + 1;
    const chips = Object.entries(by)
      .sort((a, b) => b[1] - a[1])
      .map(([k, n]) => '<span class="chip ' + (ORIGIN_CHIP[k] || "") + '">' + esc(k) + " <b>" + n + "</b></span>")
      .join("");
    countsEl.innerHTML =
      (query ? '<span class="chip info">' + all.length + " of " + total + "</span>" : "") + chips;
  }

  function skillRow(s) {
    return (
      '<div class="skrow">' +
      '<span class="skrow-name" title="' + esc(s.dir || "") + '">' + esc(s.name || "?") + "</span>" +
      '<span class="skrow-origin"><span class="chip ' + (ORIGIN_CHIP[s.origin] || "") + '">' + esc(s.origin || "agent") + "</span></span>" +
      '<span class="skrow-desc" title="' + esc(s.description || "") + '">' + esc(s.description || "") + "</span>" +
      "</div>"
    );
  }

  function renderGroups() {
    const cats = filterCategories(dataset(), query);
    const rows = cats.reduce((a, c) => a + (c.skills || []).length, 0);
    if (!cats.length) {
      groupsEl.innerHTML = '<p class="empty">' + (query ? "Nothing matches." : "This agent carries no skills.") + "</p>";
      return;
    }
    groupsEl.innerHTML = cats
      .map((c) => {
        const key = active + "/" + (c.name || "misc");
        const isOpen = open.has(key) || (!touched && (rows <= 40 || query));
        return (
          '<div class="skgroup' + (isOpen ? " open" : "") + '" data-k="' + esc(key) + '">' +
          '<button class="skgroup-head" type="button"><span>' + esc(c.name || "misc") + '</span><span class="count dim">' + (c.skills || []).length + "</span></button>" +
          '<div class="skgroup-items">' + (c.skills || []).map(skillRow).join("") + "</div></div>"
        );
      })
      .join("");
  }

  function renderBelt() {
    if (!beltWrap) return;
    beltWrap.classList.toggle("gone", active !== "hermes");
    if (active !== "hermes" || !hermes) return;
    const belt = hermes.toolbelt || [];
    beltEl.innerHTML = belt.length
      ? belt
          .map((f) => {
            const tools = f.tools || [];
            const shown = tools.slice(0, 12)
              .map((t) => '<span class="chip">' + esc(t) + "</span>")
              .join("");
            const rest = tools.length > 12 ? '<span class="chip belt-more" data-n="' + esc(f.family) + '">+' + (tools.length - 12) + "</span>" : "";
            return (
              '<div class="belt-family">' + esc(f.family || "") + "</div>" +
              '<div class="belt-tools">' + shown + rest + "</div>"
            );
          })
          .join("")
      : '<p class="muted">No tools enabled.</p>';
  }

  function paint() {
    renderTabs();
    renderCounts(filterCategories(dataset(), query));
    renderGroups();
    renderBelt();
  }

  tabsEl.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-h]");
    if (!btn) return;
    active = btn.dataset.h;
    if (searchEl) searchEl.value = "";
    query = "";
    paint();
  });

  groupsEl.addEventListener("click", (e) => {
    const head = e.target.closest(".skgroup-head");
    if (!head) return;
    const g = head.closest(".skgroup");
    const k = g.dataset.k;
    touched = true;
    if (open.has(k)) open.delete(k);
    else open.add(k);
    g.classList.toggle("open");
  });

  beltEl.addEventListener("click", (e) => {
    const more = e.target.closest(".belt-more");
    if (!more) return;
    const fam = more.dataset.n;
    const f = (hermes.toolbelt || []).find((x) => x.family === fam);
    if (!f) return;
    const wrap = more.parentElement;
    wrap.innerHTML = (f.tools || []).map((t) => '<span class="chip">' + esc(t) + "</span>").join("");
  });

  if (searchEl) {
    let debounce = 0;
    searchEl.addEventListener("input", () => {
      clearTimeout(debounce);
      debounce = setTimeout(() => {
        query = searchEl.value.trim();
        renderCounts(filterCategories(dataset(), query));
        renderGroups();
      }, 120);
    });
  }

  async function load() {
    try {
      hermes = await api.hermesSkills();
    } catch (err) {
      hermes = null;
      groupsEl.innerHTML = '<p class="muted">The daemon is not running, so there are no skills to show.</p>';
    }
    try {
      harnesses = (await api.harnesses()).harnesses || [];
    } catch (err) {
      harnesses = [];
    }
    if (hermes || harnesses.length) paint();
  }

  load();
}
