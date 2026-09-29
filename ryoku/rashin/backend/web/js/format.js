// Shared display formatters. One copy of the byte renderer so panels that
// print sizes (memory tiles, the system tables) never drift apart.

export function humanBytes(n) {
  if (!Number.isFinite(n) || n < 0) return "--";
  if (n < 1024) return n + " B";
  const u = ["KB", "MB", "GB", "TB"];
  let v = n / 1024;
  let i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return (v < 10 ? v.toFixed(1) : String(Math.round(v))) + " " + u[i];
}
