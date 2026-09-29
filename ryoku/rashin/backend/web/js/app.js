// Console entry point: wears the desktop's palette, boots the router and each
// sheet controller once, keeps the clocks and the status lamps live.
// Everything degrades to dim placeholders when the daemon is absent.

import { initRouter } from "./router.js";
import { initVitals } from "./vitals.js";
import { initVault } from "./vault.js";
import { initAgents } from "./agents.js";
import { initMemory } from "./memory.js";
import { initSkills } from "./skills.js";
import { initAbout } from "./about.js";
import { initCode } from "./code.js";
import { initSystem, paintOverviewStrip, showSystemTab } from "./system.js";
import { initHealthBand } from "./health.js";
import { initModels } from "./models.js";
import { initTheme, heroVisible } from "./theme.js";
import { api } from "./api.js";

function lamp(sel, ok) {
  const el = document.querySelector(sel);
  if (!el) return;
  el.classList.toggle("ok", !!ok);
  el.classList.toggle("bad", ok === false);
}

async function paintStatus() {
  try {
    const s = await api.status();
    lamp("[data-s=daemon]", s.running);
    const h = s.hermes || {};
    lamp("[data-s=hermes]", h.installed && h.wired);
  } catch (err) {
    lamp("[data-s=daemon]", false);
    lamp("[data-s=hermes]", false);
  }
  try {
    const c = await api.codeStatus();
    lamp("[data-s=prowl]", c.installed && c.serving);
  } catch (err) {
    lamp("[data-s=prowl]", false);
  }
}

// The hero reads like the desktop clock: time and day period, then the day in
// words underneath.
const timeFmt = new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" });
const shortFmt = new Intl.DateTimeFormat(undefined, { hour: "2-digit", minute: "2-digit" });
const dateFmt = new Intl.DateTimeFormat(undefined, { weekday: "long", day: "numeric", month: "long" });

function tick() {
  const now = new Date();
  const parts = timeFmt.formatToParts(now);
  const period = parts.find((p) => p.type === "dayPeriod");
  const time = parts
    .filter((p) => p.type !== "dayPeriod")
    .map((p) => p.value)
    .join("")
    .trim();
  const set = (sel, v) => {
    const el = document.querySelector(sel);
    if (el && el.textContent !== v) el.textContent = v;
  };
  set("[data-hero-time]", time);
  set("[data-hero-ampm]", period ? period.value : "");
  set("[data-hero-date]", dateFmt.format(now));
  set("[data-clock]", shortFmt.format(now));
}

function boot() {
  initTheme();
  const started = {};
  initRouter((name) => {
    heroVisible(name === "overview");
    if (started[name]) return;
    started[name] = true;
    if (name === "system") initSystem(document.querySelector('[data-panel="system"]'));
    else if (name === "vault") initVault(document.querySelector('[data-panel="vault"]'));
    else if (name === "memory") initMemory(document.querySelector('[data-panel="memory"]'));
    else if (name === "skills") initSkills(document.querySelector('[data-panel="skills"]'));
    else if (name === "about") initAbout(document.querySelector('[data-panel="about"]'));
    else if (name === "agents") initAgents(document.querySelector('[data-panel="agents"]'));
    else if (name === "models") initModels(document.querySelector('[data-panel="models"]'));
  });
  initVitals(document.querySelector('[data-panel="overview"]'));
  initCode(document.querySelector('[data-panel="overview"]'));
  api.system().then(paintOverviewStrip).catch(() => {});
  initHealthBand(document.querySelector("[data-health-band]"), () => showSystemTab("doctor"));
  const origin = document.querySelector("[data-origin]");
  if (origin) origin.textContent = location.host;
  tick();
  setInterval(tick, 1000);
  paintStatus();
  setInterval(paintStatus, 5000);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot);
} else {
  boot();
}
