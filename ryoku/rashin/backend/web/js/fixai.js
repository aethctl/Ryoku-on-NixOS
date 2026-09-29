// Fix with AI, the dashboard half: a button anywhere a problem is shown hands
// that problem to the agent. The daemon briefs the agent and opens it in a
// terminal window, where it investigates and asks before it changes anything;
// the page just confirms inline. Buttons carry their request as JSON in
// data-fix.

import { api } from "./api.js";
import { escapeHtml, escapeAttr } from "./markdown.js";

export function fixButton(req, label, extraClass) {
  return (
    '<button class="btn btn-primary fix-btn' + (extraClass ? " " + extraClass : "") + '" type="button" data-fix="' +
    escapeAttr(JSON.stringify(req)) + '"><span class="fix-seal jp" aria-hidden="true">力</span>' +
    '<span class="fix-label">' + escapeHtml(label || "Fix with AI") + "</span></button>"
  );
}

async function run(btn) {
  let req;
  try {
    req = JSON.parse(btn.dataset.fix);
  } catch (err) {
    return;
  }
  const label = btn.querySelector(".fix-label");
  const before = label ? label.textContent : "";
  const scope = btn.closest("[data-fix-scope]") || btn.parentElement;
  const errEl = scope && scope.querySelector(".fix-err");
  if (errEl) {
    errEl.hidden = true;
    errEl.classList.remove("ok");
  }
  btn.disabled = true;
  btn.classList.add("busy");
  if (label) label.textContent = "Opening the agent";
  try {
    const res = await api.fix(req);
    if (errEl) {
      errEl.textContent = res && res.harness ? "Opened in a terminal with " + res.harness : "Opened in a terminal";
      errEl.classList.add("ok");
      errEl.hidden = false;
    }
  } catch (err) {
    if (errEl) {
      errEl.textContent = err.message;
      errEl.hidden = false;
    }
  } finally {
    btn.disabled = false;
    btn.classList.remove("busy");
    if (label) label.textContent = before;
  }
}

// bindFixButtons wires every current and future Fix with AI button under root.
export function bindFixButtons(root) {
  root.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-fix]");
    if (btn && root.contains(btn) && !btn.disabled) run(btn);
  });
}
