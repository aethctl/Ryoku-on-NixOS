// Overview vitals: live machine stats over /ws/vitals, falling back to 2s
// polling of /api/vitals when the socket fails. The bar widths carry the
// load; the numbers simply update.

import { api, wsUrl } from "./api.js";

export function formatBytes(n) {
  const gib = Number(n) / (1024 * 1024 * 1024);
  return gib.toFixed(1) + " GiB";
}

export function formatUptime(sec) {
  sec = Math.max(0, Math.floor(Number(sec) || 0));
  const d = Math.floor(sec / 86400);
  const h = Math.floor((sec % 86400) / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const parts = [];
  if (d) parts.push(d + "d");
  if (h || d) parts.push(h + "h");
  parts.push(m + "m");
  return parts.join(" ");
}

function setText(sel, v) {
  const el = document.querySelector(sel);
  if (el) el.textContent = v;
}

function setBar(sel, pct) {
  const bar = document.querySelector(sel);
  if (!bar) return;
  bar.style.width = Math.max(0, Math.min(100, pct)) + "%";
  const track = bar.closest(".bar");
  if (track) {
    track.classList.toggle("warn", pct >= 75 && pct < 90);
    track.classList.toggle("bad", pct >= 90);
  }
}

export function renderVitals(v) {
  if (!v || typeof v !== "object") return;
  const cpu = Number(v.cpu?.percent) || 0;
  const memPct = v.mem?.total ? (v.mem.used / v.mem.total) * 100 : 0;
  const root = (v.disks || []).find((d) => d.mount === "/") || v.disks?.[0];
  const diskPct = root?.total ? (root.used / root.total) * 100 : 0;
  const gpu = v.gpu ? Number(v.gpu.percent) || 0 : null;

  setText('[data-v="cpu-pct"]', Math.round(cpu) + "%");
  setText('[data-v="cpu-model"]', v.cpu?.model || "--");
  setBar('[data-v="cpu-bar"]', cpu);

  setText('[data-v="mem-pct"]', Math.round(memPct) + "%");
  setText('[data-v="mem-detail"]', v.mem?.total ? formatBytes(v.mem.used) + " / " + formatBytes(v.mem.total) : "--");
  setBar('[data-v="mem-bar"]', memPct);

  setText('[data-v="disk-pct"]', root?.total ? Math.round(diskPct) + "%" : "--");
  setText('[data-v="disk-detail"]', root?.total ? formatBytes(root.total - root.used) + " free / " + formatBytes(root.total) : "--");
  setBar('[data-v="disk-bar"]', diskPct);

  setText('[data-v="gpu-pct"]', gpu === null ? "sleeping" : Math.round(gpu) + "%");
  setText('[data-v="gpu-name"]', v.gpu?.name || (gpu === null ? "runtime-suspended" : "--"));
  setBar('[data-v="gpu-bar"]', gpu === null ? 0 : gpu);

  setText('[data-v="kernel"]', v.kernel || "--");
  setText('[data-v="uptime"]', v.uptime != null ? formatUptime(v.uptime) : "--");
  setText('[data-v="host"]', v.host || "");
}

export function initVitals(root) {
  if (!root) return;
  let ws = null;
  let poll = 0;
  let stopped = false;

  function startPolling() {
    if (poll || stopped) return;
    poll = setInterval(() => {
      api.vitals().then(renderVitals).catch(() => {});
    }, 2000);
  }
  function stopPolling() {
    clearInterval(poll);
    poll = 0;
  }

  function connect() {
    if (stopped) return;
    try {
      ws = new WebSocket(wsUrl("/ws/vitals"));
    } catch (err) {
      startPolling();
      return;
    }
    ws.onmessage = (e) => {
      try {
        renderVitals(JSON.parse(e.data));
      } catch (err) {
        /* keep the last frame */
      }
    };
    ws.onclose = () => {
      ws = null;
      if (!stopped) {
        startPolling();
        setTimeout(connect, 5000);
      }
    };
    ws.onerror = () => {
      try {
        ws.close();
      } catch (err) {
        /* onclose handles the fallback */
      }
    };
    ws.onopen = () => stopPolling();
  }

  api.vitals().then(renderVitals).catch(() => {});
  connect();

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      stopped = true;
      stopPolling();
      if (ws) {
        try {
          ws.close();
        } catch (err) {
          /* already gone */
        }
        ws = null;
      }
    } else {
      stopped = false;
      connect();
    }
  });
}
