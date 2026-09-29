// Hash router: shows one sheet, marks its island tab, and names the tab
// title. A sheet eases in once when it is swapped to; nothing reflows after.

const PANELS = {
  overview: "Overview",
  system: "System",
  vault: "Vault",
  memory: "Memory",
  skills: "Skills",
  agents: "Agents",
  models: "Models",
  about: "About",
};

function current() {
  const h = location.hash.replace(/^#\/?/, "");
  return h in PANELS ? h : "overview";
}

export function initRouter(onChange) {
  const panels = document.querySelectorAll("[data-panel]");
  const links = document.querySelectorAll("[data-nav]");
  let shown = null;

  function show(name) {
    panels.forEach((p) => {
      const on = p.dataset.panel === name;
      p.hidden = !on;
      if (on && shown !== null && shown !== name) {
        p.classList.remove("entering");
        void p.offsetWidth;
        p.classList.add("entering");
      }
    });
    links.forEach((l) => {
      const on = l.dataset.nav === name;
      l.classList.toggle("active", on);
      if (on) l.setAttribute("aria-current", "page");
      else l.removeAttribute("aria-current");
    });
    document.title = name === "overview" ? "Rashin" : PANELS[name] + " · Rashin";
    if (shown !== name) window.scrollTo(0, 0);
    shown = name;
    if (onChange) onChange(name);
  }

  addEventListener("hashchange", () => show(current()));
  show(current());
}
