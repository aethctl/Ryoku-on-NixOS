// Ryoku's health check (`ryoku doctor --json`, run read-only by the daemon),
// shared by the Overview's health band and the System sheet's Doctor tab. One
// scan feeds both; the daemon caches it, so opening either never reruns a
// check that just ran.

import { api } from "./api.js";
import { escapeHtml } from "./markdown.js";
import { fixButton, bindFixButtons } from "./fixai.js";

const ATTENTION = { fail: 0, warn: 1, todo: 2 };

let scan = null;
let loading = false;
const listeners = new Set();

export const healthScan = () => scan;
export const healthLoading = () => loading;

// healthIssues are the findings doctor could not settle on its own, most
// serious first.
export function healthIssues() {
  return ((scan && scan.findings) || [])
    .filter((f) => f.status in ATTENTION)
    .sort((a, b) => ATTENTION[a.status] - ATTENTION[b.status]);
}

export function onHealth(fn) {
  listeners.add(fn);
}

function notify() {
  listeners.forEach((fn) => fn());
}

export async function loadHealth(refresh) {
  if (loading) return;
  loading = true;
  notify();
  try {
    scan = await api.doctor(refresh);
  } catch (err) {
    scan = { error: "The daemon is not answering.", findings: [] };
  }
  loading = false;
  notify();
}

// The overview band appears only when something needs a person: a line that
// says what, the agent's button, and a way to read the findings first.
function paintBand(band, openDoctor) {
  const issues = healthIssues().filter((f) => f.status !== "todo");
  if (!issues.length) {
    band.hidden = true;
    return;
  }
  const lead =
    issues.length === 1
      ? "The health check found one thing to look at: " + issues[0].name + "."
      : "The health check found " + issues.length + " things to look at.";
  band.innerHTML =
    '<span class="band-seal jp" aria-hidden="true">力</span>' +
    '<p class="band-text">' + escapeHtml(lead) + "</p>" +
    '<button class="btn btn-ghost" type="button" data-band-open>See findings</button>' +
    fixButton({ kind: "doctor" }, issues.length === 1 ? "Fix with AI" : "Fix all with AI") +
    '<p class="fix-err" hidden></p>';
  band.hidden = false;
  band.querySelector("[data-band-open]").addEventListener("click", openDoctor);
}

export function initHealthBand(band, openDoctor) {
  if (!band) return;
  bindFixButtons(band);
  onHealth(() => paintBand(band, openDoctor));
  loadHealth(false);
}
