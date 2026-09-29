// The SYSTEM panel: this machine as a home server. One tab per surface, dense
// tables, and a search box that filters the active tab. The panel itself only
// reads: tips and Ryoku's health check (the Doctor tab) show what is wrong,
// their commands copy to your clipboard, and Fix with AI opens the agent in a
// terminal, briefed on the problem, to investigate and ask before it changes
// anything.

import { escapeHtml, escapeAttr } from "./markdown.js";
import { api } from "./api.js";
import { humanBytes } from "./format.js";
import { fixButton, bindFixButtons } from "./fixai.js";
import { healthScan, healthLoading, healthIssues, loadHealth, onHealth } from "./health.js";

const REFRESH_MS = 30_000;
const esc = (s) => escapeHtml(String(s == null ? "" : s));

let active = "services";
let serviceSub = "running";
let query = "";
let inv = null;
let timer = 0;
let panelRoot = null;

function ago(iso) {
  if (!iso) return "";
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (!Number.isFinite(s) || s < 0) return "";
  if (s < 45) return "just now";
  if (s < 3600) return Math.round(s / 60) + " min ago";
  return Math.round(s / 3600) + " h ago";
}

function shortDate(s) {
  if (!s || s === "-") return "-";
  const d = new Date(s);
  if (isNaN(d)) return s;
  return d.toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

function isWild(a) {
  return a === "*" || a === "::" || a === "0.0.0.0";
}

function table(cols, rows) {
  if (!rows.length) return '<p class="empty">Nothing here.</p>';
  return (
    '<table class="data"><thead><tr>' +
    cols.map((c) => "<th" + (c[2] ? ' class="r"' : "") + ">" + c[0] + "</th>").join("") +
    "</tr></thead><tbody>" +
    rows
      .map(
        (r) =>
          "<tr>" +
          cols.map((c) => "<td" + (c[2] ? ' class="r"' : "") + ">" + c[1](r) + "</td>").join("") +
          "</tr>"
      )
      .join("") +
    "</tbody></table>"
  );
}

function note(text) {
  return text ? '<p class="muted">' + esc(text) + "</p>" : "";
}

function matches(cells) {
  if (!query) return true;
  return cells.join(" ").toLowerCase().includes(query);
}

// ---- tabs ----

function renderServices() {
  const s = inv.services || {};
  const subs = [
    ["running", "Running", (s.running || []).length],
    ["stopped", "Stopped", (s.stopped || []).length],
    ["user", "User", (s.userOnly || []).length],
  ];
  const seg =
    '<div class="seg">' +
    subs
      .map(
        ([k, label, n]) =>
          '<button class="seg-btn' + (serviceSub === k ? " active" : "") + '" data-sub="' +
          k + '" type="button">' + label + " <b>" + n + "</b></button>"
      )
      .join("") +
    "</div>";
  const rows = s[serviceSub] || [];
  const filtered = rows.filter((r) => matches([r.name, r.activeState, r.subState, r.description]));
  return (
    seg +
    (s.note && serviceSub !== "running" ? note(s.note) : "") +
    table(
      [
        ["Unit", (r) => '<span class="mono">' + esc(r.name) + "</span>"],
        ["", (r) =>
          r.activeState === "active" && r.subState === "running"
            ? '<span class="state ok">running</span>'
            : r.activeState === "failed"
              ? '<span class="state bad">failed</span>'
              : '<span class="state idle">' + esc(r.activeState) + "</span>"],
        ["Detail", (r) => '<span class="muted" title="' + esc(r.description) + '">' + esc(r.description) + "</span>"],
      ],
      filtered
    )
  );
}

function renderTimers() {
  const t = inv.timers || {};
  const rows = [...(t.active || []), ...(t.passive || [])];
  const filtered = rows.filter((r) => matches([r.unit, r.activates, r.nextRun, r.left]));
  return table(
    [
      ["Timer", (r) => '<span class="mono">' + esc(r.unit) + "</span>"],
      ["Next", (r) =>
        r.passive
          ? '<span class="state idle">idle</span>'
          : r.left
            ? esc(r.left) + ' <span class="dim">' + shortDate(r.nextRun) + "</span>"
            : shortDate(r.nextRun)],
      ["Fires", (r) => '<span class="mono dim">' + esc(r.activates || "-") + "</span>"],
    ],
    filtered
  );
}

function renderSchedules() {
  const s = inv.schedules || {};
  const rows = [
    ...(s.crontabs || []).map((e) => ({ ...e, kind: "" })),
    ...(s.anacron || []).map((e) => ({ ...e, kind: "periodic" })),
    ...(s.atJobs || []).map((e) => ({ ...e, kind: "one-shot" })),
  ];
  const head =
    (s.cronActive === false
      ? '<p><span class="chip bad">cron daemon stopped</span></p>'
      : "") + note(s.note);
  const filtered = rows.filter((r) => matches([r.schedule, r.command, r.origin, r.kind]));
  return (
    head +
    table(
      [
        ["Schedule", (r) => '<span class="mono">' + esc(r.schedule) + "</span>"],
        ["Command", (r) => '<span class="mono muted" title="' + esc(r.command) + '">' + esc(r.command) + "</span>"],
        ["Kind", (r) => (r.kind ? '<span class="chip">' + esc(r.kind) + "</span>" : "")],
        ["Source", (r) => '<span class="dim">' + esc(r.origin) + "</span>"],
      ],
      filtered
    )
  );
}

function renderContainers() {
  const c = inv.containers || {};
  if (!c.installed || !(c.rows || []).length) return note(c.note || "docker not installed");
  const filtered = c.rows.filter((r) => matches([r.name, r.image, r.state, r.status]));
  return table(
    [
      ["Name", (r) => '<span class="mono">' + esc(r.name) + "</span>"],
      ["", (r) => (r.state === "running" ? '<span class="state ok">up</span>' : '<span class="state idle">' + esc(r.state) + "</span>")],
      ["Image", (r) => '<span class="mono muted" title="' + esc(r.image) + '">' + esc(r.image) + "</span>"],
      ["Status", (r) => '<span class="muted">' + esc(r.status) + "</span>"],
      ["Created", (r) => '<span class="dim">' + esc(r.created) + "</span>"],
    ],
    filtered
  );
}

function renderListeners() {
  const l = inv.listeners || {};
  const rank = (r) => (r.loopback ? 2 : isWild(r.address) ? 1 : 0);
  const rows = [...(l.rows || [])].sort((a, b) => rank(a) - rank(b) || a.port - b.port);
  const filtered = rows.filter((r) => matches([r.proto, r.address, String(r.port), r.process]));
  return table(
    [
      ["Proto", (r) => '<span class="chip">' + esc(r.proto) + "</span>"],
      ["Address", (r) => '<span class="mono">' + esc(r.address) + ":" + esc(r.port) + "</span>"],
      ["Reach", (r) =>
        r.loopback
          ? '<span class="state ok">loopback</span>'
          : isWild(r.address)
            ? '<span class="state warn">all interfaces</span>'
            : '<span class="state bad">' + esc(r.address) + "</span>"],
      ["Process", (r) => '<span class="mono dim">' + esc(r.process || "-") + "</span>"],
    ],
    filtered
  );
}

function renderProcesses() {
  const p = inv.processes || {};
  const filtered = (p.rows || []).filter((r) => matches([r.command, String(r.pid)]));
  return table(
    [
      ["CPU %", (r) => '<span class="mono">' + Number(r.cpuPct).toFixed(1) + "</span>", true],
      ["PID", (r) => '<span class="mono dim">' + esc(r.pid) + "</span>", true],
      ["Command", (r) => '<span class="mono">' + esc(r.command) + "</span>"],
      ["RSS", (r) => '<span class="mono dim">' + humanBytes(r.memRss) + "</span>", true],
    ],
    filtered
  );
}

function renderMounts() {
  const m = inv.mounts || {};
  const filtered = (m.rows || []).filter((r) => matches([r.mountpoint, r.fstype, r.device]));
  return table(
    [
      ["Mount", (r) => '<span class="mono">' + esc(r.mountpoint) + "</span>"],
      ["FS", (r) => '<span class="chip">' + esc(r.fstype) + "</span>"],
      ["Size", (r) => '<span class="mono dim">' + humanBytes(r.size) + "</span>", true],
      ["Used", (r) => '<span class="mono">' + humanBytes(r.used) + "</span>", true],
      [
        "Use",
        (r) =>
          '<span class="bar' + (r.usePct >= 90 ? " bad" : r.usePct >= 75 ? " warn" : "") + '"><i style="width:' +
          Math.min(100, r.usePct).toFixed(0) + '%"></i></span> <span class="mono dim">' + r.usePct.toFixed(0) + "%</span>",
        true,
      ],
    ],
    filtered
  );
}

function cmdButton(command) {
  return (
    '<button class="cmd-btn" type="button" data-copy="' + escapeAttr(command) + '"><code>' + esc(command) +
    '</code><span class="cmd-copy">copy</span></button>'
  );
}

function renderTips() {
  const tips = inv.tips || [];
  if (!tips.length) return '<p class="empty">Nothing needs attention.</p>';
  const sev = { act: ["bad", "Act"], watch: ["warn", "Watch"], info: ["info", "Info"] };
  return (
    '<p class="muted tips-line">Copy a command to look yourself, or hand the tip to the agent: it reads the logs first and asks before it changes anything.</p>' +
    tips
      .map((t) => {
        const [cls, label] = sev[t.severity] || sev.info;
        return (
          '<div class="card tip tip-' + esc(t.severity) + '" data-fix-scope>' +
          '<span class="state ' + cls + '">' + label + "</span>" +
          "<b>" + esc(t.title) + "</b>" +
          "<p>" + esc(t.detail) + "</p>" +
          '<div class="tip-actions">' +
          (t.command ? cmdButton(t.command) : "") +
          fixButton({ kind: "tip", id: t.id }) +
          "</div>" +
          '<p class="fix-err" hidden></p>' +
          "</div>"
        );
      })
      .join("")
  );
}

// ---- doctor: Ryoku's own health check, read-only ----

const DOC_STATE = {
  fail: ["bad", "Fail"],
  warn: ["warn", "Warn"],
  todo: ["info", "Doctor can fix"],
};

// remedyHtml renders doctor's remedy prose with its `command` spans as code.
function remedyHtml(s) {
  return esc(s).replace(/`([^`]+)`/g, "<code>$1</code>");
}

function renderDoctor() {
  const doc = healthScan();
  const docLoading = healthLoading();
  if (!doc) {
    return docLoading
      ? '<p class="muted">Running Ryoku\'s health check (ryoku doctor, read-only). This takes a few seconds.</p>'
      : '<p class="muted">The health check has not run yet.</p>';
  }
  if (doc.error) return '<p class="muted">' + esc(doc.error) + "</p>";
  const findings = doc.findings || [];
  const all = healthIssues();
  const issues = all.filter((f) => matches([f.name, f.detail, f.remedy]));
  const passing = findings.filter((f) => f.status === "ok" || f.status === "fixed").length;
  const notes = findings.filter((f) => f.status === "note");
  const head =
    '<div class="doc-head" data-fix-scope>' +
    '<span class="doc-sum">' + passing + " of " + findings.length + " checks pass" +
    (doc.collectedAt ? '<span class="dim"> · checked ' + esc(ago(doc.collectedAt) || "just now") + "</span>" : "") +
    "</span>" +
    '<button class="btn" type="button" data-doc-rerun' + (docLoading ? " disabled" : "") + ">" +
    (docLoading ? "Checking" : "Check again") + "</button>" +
    (all.length ? fixButton({ kind: "doctor" }, all.length === 1 ? "Fix with AI" : "Fix all with AI") : "") +
    '<p class="fix-err" hidden></p>' +
    "</div>";
  const cards = issues.length
    ? issues
        .map((f) => {
          const [cls, label] = DOC_STATE[f.status];
          return (
            '<div class="card tip doc-' + esc(f.status) + '" data-fix-scope>' +
            '<span class="state ' + cls + '">' + label + "</span>" +
            "<b>" + esc(f.name) + "</b>" +
            "<p>" + esc(f.detail) + "</p>" +
            (f.remedy ? '<p class="doc-remedy">' + remedyHtml(f.remedy) + "</p>" : "") +
            '<div class="tip-actions">' + fixButton({ kind: "doctor", name: f.name }) + "</div>" +
            '<p class="fix-err" hidden></p>' +
            "</div>"
          );
        })
        .join("")
    : '<p class="empty">' + (query ? "Nothing matches." : "Every check passes. Nothing to fix.") + "</p>";
  const noteList = notes.length
    ? '<details class="doc-notes"><summary>' + notes.length + " advisory " + (notes.length === 1 ? "note" : "notes") + "</summary>" +
      notes.map((f) => "<p><b>" + esc(f.name) + "</b> " + esc(f.detail) + "</p>").join("") +
      "</details>"
    : "";
  return head + cards + noteList;
}

function paintDoctorBadge() {
  const badge = document.querySelector("[data-badge=doctor]");
  if (!badge) return;
  const n = healthIssues().filter((f) => f.status !== "todo").length;
  badge.textContent = n || "";
  badge.classList.toggle("zero", !n);
}

const TABS = {
  services: renderServices,
  timers: renderTimers,
  schedules: renderSchedules,
  containers: renderContainers,
  listeners: renderListeners,
  processes: renderProcesses,
  mounts: renderMounts,
  doctor: renderDoctor,
  tips: renderTips,
};

// ---- shell ----

function paint(root) {
  const body = root.querySelector("[data-sys-body]");
  if (!body) return;
  if (!inv && active !== "doctor") {
    body.innerHTML = '<p class="muted">The daemon is not answering.</p>';
    return;
  }
  body.innerHTML = (TABS[active] || renderServices)();
  if (!inv) return;

  const stamp = root.querySelector("[data-sys-stamp]");
  if (stamp) {
    const total = countRows();
    const shown = body.querySelectorAll("tbody tr").length;
    stamp.textContent = (query ? shown + " of " + total + " · " : "") + "updated " + (ago(inv.collectedAt) || "-");
    stamp.classList.toggle("stale", !inv.collectedAt || Date.now() - new Date(inv.collectedAt).getTime() > 120_000);
  }
  const badge = root.querySelector("[data-badge=tips]");
  if (badge) {
    const act = (inv.tips || []).filter((t) => t.severity === "act").length;
    badge.textContent = act || "";
    badge.classList.toggle("zero", !act);
  }
}

function countRows() {
  if (!inv) return 0;
  if (active === "services") {
    const s = inv.services || {};
    return (s[serviceSub] || []).length;
  }
  if (active === "timers") return (inv.timers?.active || []).length + (inv.timers?.passive || []).length;
  if (active === "schedules") {
    const s = inv.schedules || {};
    return (s.crontabs || []).length + (s.anacron || []).length + (s.atJobs || []).length;
  }
  if (active === "containers") return (inv.containers?.rows || []).length;
  if (active === "listeners") return (inv.listeners?.rows || []).length;
  if (active === "processes") return (inv.processes?.rows || []).length;
  if (active === "mounts") return (inv.mounts?.rows || []).length;
  if (active === "doctor") return healthIssues().length;
  return (inv.tips || []).length;
}

async function refresh(root, force) {
  try {
    inv = await api.system();
  } catch (err) {
    if (!force) return;
    inv = null;
  }
  paint(root);
  paintOverviewStrip(inv);
}

function selectTab(root, name) {
  active = name;
  root.querySelectorAll("[data-sys-tabs] .seg-btn").forEach((b) => b.classList.toggle("active", b.dataset.tab === name));
  const search = root.querySelector("[data-sys-search]");
  if (search) search.value = "";
  query = "";
  paint(root);
  if (name === "doctor" && !healthScan()) loadHealth(false);
}

// showSystemTab opens the System sheet on one tab (the overview's health band
// links straight to the Doctor tab).
export function showSystemTab(name) {
  active = name;
  if (panelRoot) selectTab(panelRoot, name);
  location.hash = "#/system";
}

export function initSystem(root) {
  if (!root) return;
  panelRoot = root;
  bindFixButtons(root);
  onHealth(() => {
    paintDoctorBadge();
    if (active === "doctor") paint(root);
  });
  paintDoctorBadge();

  root.querySelector("[data-sys-tabs]").addEventListener("click", (e) => {
    const btn = e.target.closest("[data-tab]");
    if (btn) selectTab(root, btn.dataset.tab);
  });

  root.querySelector("[data-sys-body]").addEventListener("click", (e) => {
    const sub = e.target.closest("[data-sub]");
    if (sub) {
      serviceSub = sub.dataset.sub;
      paint(root);
      return;
    }
    if (e.target.closest("[data-doc-rerun]")) {
      loadHealth(true);
      return;
    }
    const cmd = e.target.closest("[data-copy]");
    if (!cmd) return;
    const span = cmd.querySelector(".cmd-copy");
    (navigator.clipboard ? navigator.clipboard.writeText(cmd.getAttribute("data-copy")) : Promise.reject()).then(
      () => {
        if (span) {
          span.textContent = "copied";
          setTimeout(() => (span.textContent = "copy"), 1200);
        }
      },
      () => {}
    );
  });

  const search = root.querySelector("[data-sys-search]");
  if (search) {
    search.addEventListener("input", () => {
      query = search.value.trim().toLowerCase();
      paint(root);
    });
  }

  const rescan = root.querySelector("[data-sys-refresh]");
  if (rescan)
    rescan.addEventListener("click", () => {
      if (active === "doctor") loadHealth(true);
      else refresh(root, true);
    });

  selectTab(root, active);
  refresh(root, true);
  timer = setInterval(() => {
    if (!root.hidden && !document.hidden) refresh(root, false);
  }, REFRESH_MS);
}

// Overview strip: the same snapshot feeds the summary card on the poster page.
export function paintOverviewStrip(inv) {
  if (!inv) return;
  const get = (k) => document.querySelector('[data-sys="' + k + '"]');
  if (!get("services")) return;
  const s = inv.services || {};
  const t = inv.timers || {};
  const c = inv.containers || {};
  const l = inv.listeners || {};
  const tips = inv.tips || [];
  const act = tips.filter((x) => x.severity === "act").length;
  get("services").textContent = (s.runningN || 0) + "/" + (s.totalN || 0);
  get("timers").textContent = (t.active || []).length + ((t.passive || []).length ? " · " + t.passive.length + " idle" : "");
  get("containers").textContent = (c.runningN || 0) + "/" + (c.totalN || 0);
  get("listeners").textContent = String((l.rows || []).length);
  get("tips").textContent = act ? act + " act · " + tips.length : String(tips.length);
  const side = document.querySelector("[data-badge=system]");
  if (side) {
    side.textContent = act || "";
    side.classList.toggle("zero", !act);
  }
}
