// The page wears the desktop's palette. /api/theme resolves the Material roles
// through the same chain Tokens.qml uses (named scheme, then the wallpaper,
// then the signature default); this maps them onto base.css's tokens and
// repaints when the wallpaper or scheme changes. The overview hero shows the
// wallpaper itself, playing a live one muted.

import { api } from "./api.js";

const ROLE_VARS = {
  surface: "--paper",
  surfaceContainerLow: "--paper-lift",
  onSurface: "--ink",
  onSurfaceVariant: "--ink-dim",
  inverseSurface: "--bone",
  inverseOnSurface: "--ink-on-bone",
  primary: "--sun",
};

let lastRoles = "";
let lastWall = "";

// isLight mirrors Tokens.light: a surface brighter than mid-grey is a light
// scheme, and native controls (scrollbars, inputs) should follow it.
export function isLight(hex) {
  const m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i.exec(hex || "");
  if (!m) return false;
  const [r, g, b] = m.slice(1).map((h) => parseInt(h, 16) / 255);
  return 0.299 * r + 0.587 * g + 0.114 * b > 0.5;
}

export function applyRoles(roles, style) {
  for (const [role, cssVar] of Object.entries(ROLE_VARS)) {
    const v = roles && roles[role];
    if (typeof v === "string" && /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v)) style.setProperty(cssVar, v);
  }
  style.setProperty("color-scheme", isLight(roles && roles.surface) ? "light" : "dark");
}

function paintWallpaper(wall) {
  const img = document.querySelector("[data-hero-img]");
  const video = document.querySelector("[data-hero-video]");
  const hero = document.querySelector("[data-hero]");
  if (!img || !video || !hero) return;
  if (!wall || !wall.available) {
    img.hidden = true;
    video.hidden = true;
    video.removeAttribute("src");
    hero.classList.remove("has-art");
    return;
  }
  const src = "/api/wallpaper?rev=" + encodeURIComponent(wall.rev || "");
  const shown = wall.kind === "video" ? video : img;
  const other = shown === video ? img : video;
  other.hidden = true;
  if (other === video) {
    video.pause();
    video.removeAttribute("src");
  }
  shown.classList.remove("loaded");
  shown.onload = shown.onloadeddata = () => shown.classList.add("loaded");
  shown.src = src;
  shown.hidden = false;
  if (shown === video) video.play().catch(() => {});
  hero.classList.add("has-art");
}

async function refresh() {
  let t;
  try {
    t = await api.theme();
  } catch (err) {
    return;
  }
  const roles = JSON.stringify(t.roles || {});
  if (roles !== lastRoles) {
    lastRoles = roles;
    applyRoles(t.roles, document.documentElement.style);
    document.dispatchEvent(new CustomEvent("rashin:theme"));
  }
  document.documentElement.classList.toggle("reduce-motion", !!t.reduceMotion);
  const wall = JSON.stringify(t.wallpaper || {});
  if (wall !== lastWall) {
    lastWall = wall;
    paintWallpaper(t.wallpaper);
  }
}

// A live wallpaper only plays while the overview is on screen.
export function heroVisible(visible) {
  const video = document.querySelector("[data-hero-video]");
  if (!video || video.hidden) return;
  if (visible && !document.hidden) video.play().catch(() => {});
  else video.pause();
}

export function initTheme() {
  refresh();
  setInterval(() => {
    if (!document.hidden) refresh();
  }, 15000);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) refresh();
    heroVisible(location.hash.replace(/^#\/?/, "") in { "": 1, overview: 1 });
  });
}
