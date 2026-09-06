package main

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Vault generated content lives between these markers. Reindex rewrites only
// the fenced region; anything a user or agent writes outside it survives.
const (
	vaultFenceBegin = "<!-- rashin:generated:begin -->"
	vaultFenceEnd   = "<!-- rashin:generated:end -->"
)

// The desktop map's "Bar and dock" section is fenced with its own markers
// inside the generated body, so the bar guide can be located and regenerated on
// its own. They never collide with the outer markers: the " bar" suffix sits
// before the closing "-->", so the outer begin/end are not substrings of these.
const (
	vaultBarFenceBegin = "<!-- rashin:generated:begin bar -->"
	vaultBarFenceEnd   = "<!-- rashin:generated:end bar -->"
)

// generatedFiles are the vault docs Reindex owns end to end. Everything else in
// the vault belongs to the user or an agent.
var generatedFiles = map[string]bool{
	"system.md":     true,
	"desktop.md":    true,
	"packages.md":   true,
	"ryoku-repo.md": true,
	"user.md":       true,
	"habits.md":     true,
}

// AgentsTemplate is the vault entry contract, written to AGENTS.md once. It is
// user and agent owned afterwards, so it carries no machine-specific paths: the
// live map lives in the regenerated system.md and desktop.md.
const AgentsTemplate = "# Ryoku system vault\n" +
	"\n" +
	"This is the shared knowledge base for every coding agent on this machine\n" +
	"(Hyprland desktop, managed by Ryoku). Read it before exploring\n" +
	"the filesystem or guessing where things live.\n" +
	"\n" +
	"## The one rule\n" +
	"\n" +
	"Read `desktop.md` before searching the filesystem. It maps every subsystem to\n" +
	"its config path, the binary that owns it, and how to reload it. Guessing paths\n" +
	"wastes tokens the map already spent.\n" +
	"\n" +
	"To change the desktop, use the `ryoku` skill (linked into your skills dir;\n" +
	"`desktop.md` names its path): commands, never edits to shipped files. A new\n" +
	"bar widget is a plugin, per the skill's `plugins.md`.\n" +
	"\n" +
	"## What is here\n" +
	"\n" +
	"- `system.md` generated: hardware, kernel, GPU, disks, displays.\n" +
	"- `desktop.md` generated: the Ryoku map (configs, owners, reload commands).\n" +
	"- `packages.md` generated: installed package counts, the explicit set, updates.\n" +
	"- `ryoku-repo.md` generated: the Ryoku source tree map (pre-indexed, ships with the system).\n" +
	"- `user.md` generated: where this user's config diverges from the shipped baseline.\n" +
	"- `habits.md` generated: this user's directories, tool stack, and shell rhythms.\n" +
	"- `memory/` durable notes agents keep across sessions (Hermes MEMORY.md lives here).\n" +
	"- `journal/` dated notes, one file per day named `YYYY-MM-DD.md`.\n" +
	"\n" +
	"## Rules\n" +
	"\n" +
	"- The generated files are read only. Their content between the\n" +
	"  `rashin:generated` markers is overwritten on every reindex; edits there are\n" +
	"  lost. Write anything durable to `memory/` or `journal/` instead.\n" +
	"- Changes listed in `user.md` are the user's own; never revert them to\n" +
	"  shipped defaults without being asked.\n" +
	"- You may add prose outside the generated markers in those files; it is kept.\n" +
	"- This file (AGENTS.md) is yours to extend. `CLAUDE.md` is a symlink to it.\n"

// buildFence wraps a generated body in the vault markers, normalising trailing
// whitespace so repeated runs are byte stable.
func buildFence(gen string) string {
	return vaultFenceBegin + "\n" + strings.TrimRight(gen, "\n") + "\n" + vaultFenceEnd
}

// ReplaceFenced rewrites the region between the vault markers with gen. When the
// markers are absent (a first write) it writes the generated body first, then
// the existing document, so hand-authored preamble is preserved below the fence.
func ReplaceFenced(doc, gen string) string {
	fence := buildFence(gen)
	bi := strings.Index(doc, vaultFenceBegin)
	ei := strings.Index(doc, vaultFenceEnd)
	if bi >= 0 && ei > bi {
		before := doc[:bi]
		after := doc[ei+len(vaultFenceEnd):]
		return before + fence + after
	}
	if strings.TrimSpace(doc) == "" {
		return fence + "\n"
	}
	if !strings.HasSuffix(doc, "\n") {
		doc += "\n"
	}
	return fence + "\n\n" + doc
}

// VaultFile is one entry in the vault tree exposed over /api/vault.
type VaultFile struct {
	Path      string    `json:"path"`
	Size      int64     `json:"size"`
	Mtime     time.Time `json:"mtime"`
	Generated bool      `json:"generated"`
}

// VaultTree walks the vault recursively, returning files (never directories)
// sorted by path. Symlinks (CLAUDE.md) are resolved so size and mtime reflect
// the target; broken links are skipped.
func VaultTree() ([]VaultFile, error) {
	root := VaultDir()
	var out []VaultFile
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			if p == root {
				return err
			}
			return nil
		}
		if d.IsDir() {
			return nil
		}
		rel, rerr := filepath.Rel(root, p)
		if rerr != nil {
			return nil
		}
		fi, serr := os.Stat(p) // follows symlinks
		if serr != nil {
			return nil
		}
		if fi.IsDir() {
			return nil
		}
		rel = filepath.ToSlash(rel)
		out = append(out, VaultFile{
			Path:      rel,
			Size:      fi.Size(),
			Mtime:     fi.ModTime(),
			Generated: generatedFiles[rel],
		})
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	return out, nil
}

// ReadVaultFile returns a vault file's bytes, guarding against path traversal
// and absolute paths: rel must resolve inside the vault root.
func ReadVaultFile(rel string) ([]byte, error) {
	if rel == "" || filepath.IsAbs(rel) {
		return nil, os.ErrInvalid
	}
	root := VaultDir()
	clean := filepath.Clean(filepath.Join(root, filepath.FromSlash(rel)))
	prefix := root + string(os.PathSeparator)
	if clean != root && !strings.HasPrefix(clean, prefix) {
		return nil, os.ErrInvalid
	}
	return os.ReadFile(clean)
}

// VaultStats reports the file count, the newest generated-file mtime (the last
// reindex time), and whether the vault directory exists.
func VaultStats() (files int, lastIndexed time.Time, exists bool) {
	root := VaultDir()
	if fi, err := os.Stat(root); err != nil || !fi.IsDir() {
		return 0, time.Time{}, false
	}
	exists = true
	tree, err := VaultTree()
	if err != nil {
		return 0, time.Time{}, true
	}
	files = len(tree)
	for _, f := range tree {
		if f.Generated && f.Mtime.After(lastIndexed) {
			lastIndexed = f.Mtime
		}
	}
	return files, lastIndexed, exists
}

// EnsureVault creates the vault skeleton: the root, memory/ and journal/, the
// AGENTS.md contract (only when absent, so user edits survive), and the
// CLAUDE.md symlink Claude Code reads.
func EnsureVault() error {
	root := VaultDir()
	for _, d := range []string{root, filepath.Join(root, "memory"), filepath.Join(root, "journal")} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
	}
	agents := filepath.Join(root, "AGENTS.md")
	if _, err := os.Stat(agents); os.IsNotExist(err) {
		if err := atomicWrite(agents, []byte(AgentsTemplate), 0o644); err != nil {
			return err
		}
	}
	claude := filepath.Join(root, "CLAUDE.md")
	if _, err := os.Lstat(claude); os.IsNotExist(err) {
		if err := os.Symlink("AGENTS.md", claude); err != nil {
			return err
		}
	}
	return nil
}

// atomicWrite writes via a temp file in the same directory then renames, so a
// reader never sees a partial file.
func atomicWrite(path string, data []byte, perm os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, perm); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return err
	}
	return nil
}
