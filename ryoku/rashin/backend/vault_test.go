package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func vaultEnv(t *testing.T) string {
	t.Helper()
	h := t.TempDir()
	t.Setenv("HOME", h)
	t.Setenv("XDG_DATA_HOME", filepath.Join(h, ".local", "share"))
	vault := filepath.Join(h, "vault")
	t.Setenv("RYOKU_RASHIN_VAULT", vault)
	return vault
}

func TestReplaceFencedFirstWrite(t *testing.T) {
	doc := "user preamble\n"
	out := ReplaceFenced(doc, "GEN")
	if !strings.Contains(out, vaultFenceBegin) || !strings.Contains(out, vaultFenceEnd) {
		t.Fatal("first write did not add fence markers")
	}
	if !strings.Contains(out, "GEN") || !strings.Contains(out, "user preamble") {
		t.Fatalf("first write lost content: %q", out)
	}
	if strings.Index(out, "GEN") > strings.Index(out, "user preamble") {
		t.Fatal("generated body must precede existing content on first write")
	}
}

func TestReplaceFencedIdempotent(t *testing.T) {
	a := ReplaceFenced("", "BODY")
	b := ReplaceFenced(a, "BODY")
	if a != b {
		t.Fatalf("ReplaceFenced not idempotent:\n%q\nvs\n%q", a, b)
	}
	// Regeneration rewrites only the fenced region and keeps surrounding text.
	seeded := "HEADER\n\n" + vaultFenceBegin + "\nOLD\n" + vaultFenceEnd + "\ntrailer\n"
	got := ReplaceFenced(seeded, "NEW")
	if strings.Contains(got, "OLD") {
		t.Fatalf("regeneration kept stale body: %q", got)
	}
	if !strings.Contains(got, "NEW") || !strings.Contains(got, "HEADER") || !strings.Contains(got, "trailer") {
		t.Fatalf("regeneration clobbered surrounding text: %q", got)
	}
	if ReplaceFenced(got, "NEW") != got {
		t.Fatal("regeneration not idempotent on a seeded doc")
	}
}

func TestReadVaultFileTraversal(t *testing.T) {
	vault := vaultEnv(t)
	if err := os.MkdirAll(vault, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(vault, "system.md"), []byte("ok"), 0o644); err != nil {
		t.Fatal(err)
	}
	if b, err := ReadVaultFile("system.md"); err != nil || string(b) != "ok" {
		t.Fatalf("ReadVaultFile(system.md) = %q, %v", b, err)
	}
	for _, bad := range []string{"", "../../etc/passwd", "/etc/passwd", "../vault-sibling", "a/../../b"} {
		if _, err := ReadVaultFile(bad); err == nil {
			t.Fatalf("ReadVaultFile(%q) should be rejected", bad)
		}
	}
}

func TestEnsureVault(t *testing.T) {
	vault := vaultEnv(t)
	if err := EnsureVault(); err != nil {
		t.Fatalf("EnsureVault: %v", err)
	}
	for _, d := range []string{"memory", "journal"} {
		if fi, err := os.Stat(filepath.Join(vault, d)); err != nil || !fi.IsDir() {
			t.Fatalf("expected dir %s", d)
		}
	}
	ag, err := os.ReadFile(filepath.Join(vault, "AGENTS.md"))
	if err != nil {
		t.Fatalf("AGENTS.md missing: %v", err)
	}
	// AGENTS.md now carries the template inside the generated fence, so a later
	// template change reaches an existing vault; the raw template is no longer
	// the whole file.
	if !strings.Contains(string(ag), vaultFenceBegin) || !strings.Contains(string(ag), "## The one rule") {
		t.Fatalf("AGENTS.md missing the fenced template body:\n%s", ag)
	}
	target, err := os.Readlink(filepath.Join(vault, "CLAUDE.md"))
	if err != nil {
		t.Fatalf("CLAUDE.md not a symlink: %v", err)
	}
	if filepath.Base(target) != "AGENTS.md" {
		t.Fatalf("CLAUDE.md -> %q; want AGENTS.md", target)
	}
	// A second run rewrites the fence but is byte-stable, so the file is unchanged.
	if err := EnsureVault(); err != nil {
		t.Fatalf("second EnsureVault: %v", err)
	}
	if ag2, _ := os.ReadFile(filepath.Join(vault, "AGENTS.md")); string(ag2) != string(ag) {
		t.Fatal("EnsureVault was not byte-stable across runs")
	}
}

// EnsureVault must refresh the fenced template on an already-provisioned vault
// while keeping any prose the user or an agent added outside the markers, so
// the delivery-critical rewrite never clobbers hand-authored notes.
func TestEnsureVaultRefreshesFenceKeepingProse(t *testing.T) {
	vault := vaultEnv(t)
	if err := os.MkdirAll(vault, 0o755); err != nil {
		t.Fatal(err)
	}
	userProse := "## My own notes\n\nkeep this line\n"
	seeded := ReplaceFenced("", "STALE GENERATED BODY") + "\n" + userProse
	if err := os.WriteFile(filepath.Join(vault, "AGENTS.md"), []byte(seeded), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := EnsureVault(); err != nil {
		t.Fatalf("EnsureVault: %v", err)
	}
	got := readFileOrEmpty(filepath.Join(vault, "AGENTS.md"))
	if strings.Contains(got, "STALE GENERATED BODY") {
		t.Fatalf("stale fenced body survived the rewrite:\n%s", got)
	}
	if !strings.Contains(got, "## The one rule") {
		t.Fatalf("template body not refreshed into the fence:\n%s", got)
	}
	if !strings.Contains(got, "keep this line") {
		t.Fatalf("user prose outside the fence was lost:\n%s", got)
	}
}

func TestEnsureVaultStripsLegacyContract(t *testing.T) {
	vault := vaultEnv(t)
	if err := os.MkdirAll(vault, 0o755); err != nil {
		t.Fatal(err)
	}
	// The pre-fence AGENTS.md: the write-once contract (title through its
	// final line, the variant that shipped without the habits row) plus one
	// note an agent added underneath.
	seeded := "# Ryoku system vault\n" +
		"\n" +
		"This is the shared knowledge base for every coding agent on this machine\n" +
		"(Arch Linux, Hyprland desktop, managed by Ryoku). Read it before exploring\n" +
		"the filesystem or guessing where things live.\n" +
		"\n" +
		"## Rules\n" +
		"\n" +
		"- Changes listed in `user.md` are the user's own; never revert them to\n" +
		"  shipped defaults without being asked.\n" +
		"- This file (AGENTS.md) is yours to extend. `CLAUDE.md` is a symlink to it.\n" +
		"\n" +
		"## My own note\n\nthe agent's addition\n"
	if err := os.WriteFile(filepath.Join(vault, "AGENTS.md"), []byte(seeded), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := EnsureVault(); err != nil {
		t.Fatalf("EnsureVault: %v", err)
	}
	got := readFileOrEmpty(filepath.Join(vault, "AGENTS.md"))
	if strings.Contains(got, "yours to extend") {
		t.Fatalf("legacy contract survived below the fence:\n%s", got)
	}
	if n := strings.Count(got, "# Ryoku system vault"); n != 1 {
		t.Fatalf("expected one contract copy, got %d:\n%s", n, got)
	}
	if !strings.Contains(got, "the agent's addition") {
		t.Fatalf("user prose was lost:\n%s", got)
	}
	// Idempotent: a second run must not churn the file.
	if err := EnsureVault(); err != nil {
		t.Fatal(err)
	}
	if again := readFileOrEmpty(filepath.Join(vault, "AGENTS.md")); again != got {
		t.Fatalf("second EnsureVault rewrote the file differently:\n%s", again)
	}
}

func TestVaultTreeGeneratedFlag(t *testing.T) {
	vault := vaultEnv(t)
	if err := EnsureVault(); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(vault, "system.md"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(vault, "memory", "note.md"), []byte("y"), 0o644); err != nil {
		t.Fatal(err)
	}
	tree, err := VaultTree()
	if err != nil {
		t.Fatal(err)
	}
	byPath := map[string]VaultFile{}
	for _, f := range tree {
		byPath[f.Path] = f
	}
	if f, ok := byPath["system.md"]; !ok || !f.Generated {
		t.Fatalf("system.md missing or not marked generated: %+v", f)
	}
	if f, ok := byPath["memory/note.md"]; !ok || f.Generated {
		t.Fatalf("memory/note.md missing or wrongly marked generated: %+v", f)
	}
}
