// About panel: static poster copy (the WHAT / QUICK START / GO DEEPER / PRIVACY
// strings live here) with live facts from /api/about merged into THE PIECES
// table. Degrades to dim "unknown" facts when the daemon is absent; the copy
// still renders so the panel is never blank.

import { escapeHtml } from "./markdown.js";

const WHAT = [
  "Rashin is the optional local agent OS for Ryoku.",
  "It keeps a maintained map of the machine so agents read the terrain instead of rediscovering it every session.",
  "A resident Hermes agent lives in it, and this dashboard is its face.",
];

const QUICK_START = [
  "Enable Rashin in Ryoku Settings > Advanced > Rashin.",
  "Set up the Hermes agent.",
  "Chat here, or run `hermes` inside the vault.",
];

const GO_DEEPER = [
  ["hermes -h", "explore every command and configuration"],
  ["hermes gateway", "connect Telegram / Discord / WhatsApp / Slack"],
  ["hermes model", "switch the default model"],
  ["hermes tools", "enable toolsets"],
  ["ryoku-rashin -h", "daemon verbs"],
  ["prowl overview", "code intelligence on any repo"],
];

const PRIVACY =
  "Everything runs on this machine. The daemon binds 127.0.0.1 only, and nothing you do here leaves the box.";

async function getJSON(path) {
  const r = await fetch(path, { headers: { accept: "application/json" } });
  if (!r.ok) throw new Error(path + " -> " + r.status);
  return r.json();
}

// pieces(about) -> [{name, note, fact}] merging static one-liners with live
// facts. Missing facts fall back to a dim "unknown" so the table always fills.
function pieces(about) {
  about = about || {};
  const h = about.hermes || {};
  const prowl = about.prowl || {};
  const dim = (s) => '<span class="dim">' + s + "</span>";
  const vault = about.vault ? escapeHtml(about.vault) : dim("not set");
  const daemon = about.version
    ? escapeHtml("v" + about.version) + " / :" + escapeHtml(String(about.port || 3600))
    : dim("offline");
  let hermes;
  if (!h.installed) hermes = dim("not installed");
  else if (!h.configured) hermes = dim("not set up");
  else {
    const bits = [];
    if (h.version) bits.push("v" + h.version);
    if (h.model) bits.push(h.model);
    if (h.provider) bits.push(h.provider);
    hermes = bits.length ? escapeHtml(bits.join(" / ")) : "configured";
  }
  const prowlFact = prowl.installed ? "installed" : dim("absent");
  return [
    { name: "vault", note: "the map agents read", fact: vault },
    { name: "daemon", note: "serves this dashboard + the API", fact: daemon },
    { name: "dashboard", note: "what you are looking at", fact: "this page" },
    { name: "hermes", note: "the resident agent", fact: hermes },
    { name: "prowl", note: "code intelligence over your repos", fact: prowlFact },
  ];
}

// ---- DOM layer (browser only) ----------------------------------------------

export function initAbout(root) {
  const body = root.querySelector("[data-about-body]");

  function render(about) {
    const what = WHAT.map((s) => "<p>" + escapeHtml(s) + "</p>").join("");
    const pieceRows = pieces(about)
      .map(
        (p) =>
          '<tr><th class="about-key">' +
          escapeHtml(p.name) +
          '</th><td class="about-note">' +
          escapeHtml(p.note) +
          '</td><td class="about-fact">' +
          p.fact +
          "</td></tr>"
      )
      .join("");
    const steps = QUICK_START.map((s, i) => {
      const btn =
        i === 1
          ? ' <button type="button" class="btn btn-primary about-setup" data-about-setup>SET UP HERMES</button>'
          : "";
      return "<li>" + escapeHtml(s) + btn + "</li>";
    }).join("");
    const cmds = GO_DEEPER.map(
      (c) =>
        '<tr><td class="about-cmd">' +
        escapeHtml(c[0]) +
        '</td><td class="about-cmd-note">' +
        escapeHtml(c[1]) +
        "</td></tr>"
    ).join("");

    body.innerHTML =
      '<section class="about-sec"><em class="eyebrow">WHAT</em>' +
      '<div class="about-what">' +
      what +
      "</div></section>" +
      '<section class="about-sec"><em class="eyebrow">THE PIECES</em>' +
      '<table class="about-def"><tbody>' +
      pieceRows +
      "</tbody></table></section>" +
      '<section class="about-sec"><em class="eyebrow">QUICK START</em>' +
      '<ol class="about-steps">' +
      steps +
      "</ol></section>" +
      '<section class="about-sec"><em class="eyebrow">GO DEEPER</em>' +
      '<table class="about-cmds"><tbody>' +
      cmds +
      "</tbody></table></section>" +
      '<section class="about-sec"><em class="eyebrow">PRIVACY</em>' +
      '<p class="about-privacy">' +
      escapeHtml(PRIVACY) +
      "</p></section>";

    const setup = body.querySelector("[data-about-setup]");
    if (setup) setup.addEventListener("click", () => {
      location.hash = "#/agents";
    });
  }

  async function load() {
    try {
      render(await getJSON("/api/about"));
    } catch (err) {
      render(null);
    }
  }

  load();
}
