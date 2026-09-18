package main

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// catalogRevision is a stable fingerprint of what the catalogue offers: the
// sorted identity of every item (category, id, version, manifest digest) and its
// gates. It ignores volatile fields (generatedAt, offline flags, local install
// state) so it changes only when upstream content does -- a new item, a version
// bump, a changed manifest, a pause/resume, or a product newly declaring (or
// dropping) the window manager it is written for. The store compares it against
// the last acknowledged revision to light the refresh dot only on a genuine
// ryostore change.
func catalogRevision(cat Catalog) string {
	lines := make([]string, 0, len(cat.Items))
	for i := range cat.Items {
		it := &cat.Items[i]
		lines = append(lines, strings.Join([]string{it.Category, it.ID, it.Version, it.ManifestSHA256, gateFingerprint(it)}, "\x1f"))
	}
	sort.Strings(lines)
	sum := sha256.Sum256([]byte(strings.Join(lines, "\n")))
	return hex.EncodeToString(sum[:])
}

// gateFingerprint encodes an item's gates as one field of its revision line: the
// window manager it declares (or "any"), and "active" when downloads are open or
// else the paused marker with a digest of the user-facing reason. The reason is
// hashed, not embedded, so text taken from a registry can never forge a field or
// line boundary. A reason without the pause flag is ignored, exactly as the store
// ignores it.
func gateFingerprint(it *Item) string {
	manager := strings.TrimSpace(it.RequiredWindowManager)
	if manager == "" {
		manager = "any"
	}
	return manager + "\x1f" + pauseFingerprint(it)
}

// pauseFingerprint is the download half of gateFingerprint.
func pauseFingerprint(it *Item) string {
	if !it.DownloadPaused {
		return "active"
	}
	sum := sha256.Sum256([]byte(it.DownloadPauseReason))
	return "paused:" + hex.EncodeToString(sum[:8])
}

// seenRevisionPath is the last catalogue revision the user has looked at, kept
// per source (under the same per-base cache dir) so switching bases never
// cross-contaminates the "seen" baseline.
func seenRevisionPath() string {
	return filepath.Join(extrasCacheDir(), "seen-revision")
}

func readSeenRevision() string {
	b, err := os.ReadFile(seenRevisionPath())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// writeSeenRevision records rev as the acknowledged baseline. Best effort: a
// failure only means the refresh dot may show once more, never a broken store.
func writeSeenRevision(rev string) {
	if rev == "" {
		return
	}
	if err := os.MkdirAll(filepath.Dir(seenRevisionPath()), 0o755); err != nil {
		return
	}
	_ = atomicWrite(seenRevisionPath(), []byte(rev+"\n"), 0o644)
}
