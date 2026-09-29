package main

import (
	"os"
	"path/filepath"
	"testing"
)

func putFile(t *testing.T, p, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestScanHarnessSkillsFollowsSymlinkedDirs(t *testing.T) {
	home := t.TempDir()
	real := filepath.Join(home, "elsewhere", "ryoku")
	putFile(t, filepath.Join(real, "SKILL.md"), "---\nname: ryoku\ndescription: the desktop skill\n---\nbody\n")
	// wire lays skills as symlinks; the scan must count them, not skip them.
	skillsDir := filepath.Join(home, ".claude", "skills")
	if err := os.MkdirAll(skillsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(real, filepath.Join(skillsDir, "ryoku")); err != nil {
		t.Fatal(err)
	}
	putFile(t, filepath.Join(skillsDir, "plain", "SKILL.md"), "---\nname: plain\ndescription: d\n---\n")

	skills, n := scanHarnessSkills("claude", filepath.Join(home, ".claude"))
	if n != 2 || len(skills) != 2 {
		t.Fatalf("n = %d len = %d, want 2: %+v", n, len(skills), skills)
	}
	var shipped, agent bool
	for _, s := range skills {
		if s.Name == "ryoku" && s.Origin == "shipped" {
			shipped = true
		}
		if s.Name == "plain" && s.Origin == "agent" {
			agent = true
			if s.Description != "d" {
				t.Errorf("desc = %q", s.Description)
			}
		}
	}
	if !shipped || !agent {
		t.Fatalf("origin mapping wrong: %+v", skills)
	}
}

func TestScanHarnessMemories(t *testing.T) {
	home := t.TempDir()
	putFile(t, filepath.Join(home, ".hermes", "memories", "MEMORY.md"), "durable notes\n")
	putFile(t, filepath.Join(home, ".hermes", "state.db"), "sqlite")
	putFile(t, filepath.Join(home, ".codex", "AGENTS.md"), "# rules\n")

	notes := scanHarnessMemories("hermes", filepath.Join(home, ".hermes"))
	if len(notes) < 2 {
		t.Fatalf("hermes notes = %+v", notes)
	}
	var foundMd, foundDb bool
	for _, nt := range notes {
		if nt.Name == "MEMORY.md" && nt.Kind == "file" && nt.Bytes > 0 {
			foundMd = true
		}
		if nt.Name == "state.db" && nt.Kind == "db" {
			foundDb = true
		}
	}
	if !foundMd || !foundDb {
		t.Fatalf("missing file or db note: %+v", notes)
	}
	codex := scanHarnessMemories("codex", filepath.Join(home, ".codex"))
	if len(codex) != 1 || codex[0].Name != "AGENTS.md" {
		t.Fatalf("codex notes = %+v", codex)
	}
}

func TestHarnessModelChoice(t *testing.T) {
	home := t.TempDir()
	putFile(t, filepath.Join(home, "config.toml"), "model = \"gpt-5.6-sol\"\nmodel_reasoning_effort = \"high\"\n")
	m, p := harnessModelChoice("codex", home)
	if m != "gpt-5.6-sol" || p != "openai" {
		t.Fatalf("codex model = %q provider = %q", m, p)
	}
	putFile(t, filepath.Join(home, "settings.json"), `{"model":"opus"}`)
	m, _ = harnessModelChoice("claude", home)
	if m != "opus" {
		t.Fatalf("claude model = %q", m)
	}
	m, p = harnessModelChoice("gemini", home) // no model block in settings.json above
	if m != "" {
		t.Fatalf("gemini should find no model, got %q %q", m, p)
	}
}

func TestScanHarnessCredsNamesNotValues(t *testing.T) {
	t.Setenv("GEMINI_API_KEY", "super-secret-value")
	t.Setenv("KITTY_PUBLIC_KEY", "not-a-model-key")
	t.Setenv("STARSHIP_SESSION_KEY", "not-a-model-key")
	home := t.TempDir()
	putFile(t, filepath.Join(home, ".env"), "OPENAI_API_KEY=sk-real-thing\nPLAIN=ok\n")
	putFile(t, filepath.Join(home, "auth.json"), `{"OPENAI_API_KEY":"k","tokens":{"access":"x"}}`)

	creds := scanHarnessCreds("hermes", home)
	labels := map[string]string{}
	for _, c := range creds {
		labels[c.Label] = c.Kind
		if c.Label == "super-secret-value" || c.Label == "sk-real-thing" {
			t.Fatalf("credential value leaked as label: %+v", c)
		}
	}
	if _, ok := labels["OPENAI_API_KEY"]; !ok {
		t.Fatalf("env/file key not reported: %+v", creds)
	}
	if _, ok := labels["GEMINI_API_KEY"]; !ok {
		t.Fatalf("process provider key not reported: %+v", creds)
	}
	// session/tooling variables are not model credentials and must stay out
	for _, noise := range []string{"PLAIN", "KITTY_PUBLIC_KEY", "STARSHIP_SESSION_KEY"} {
		if _, ok := labels[noise]; ok {
			t.Fatalf("non-credential key reported: %s", noise)
		}
	}
	// dedupe: OPENAI_API_KEY appears in file and env; each kind once at most.
	seen := map[string]int{}
	for _, c := range creds {
		seen[c.Kind+c.Label]++
	}
	for k, v := range seen {
		if v > 1 {
			t.Fatalf("duplicate cred %s x%d", k, v)
		}
	}
}

func TestScanHarnessesShape(t *testing.T) {
	fake := t.TempDir()
	putFile(t, filepath.Join(fake, ".omp", "agent", "AGENTS.md"), "# omp\n")
	putFile(t, filepath.Join(fake, ".omp", "agent", "agent.db"), "db")
	t.Setenv("HOME", fake)
	rows := ScanHarnesses()
	if len(rows) != 6 {
		t.Fatalf("rows = %d, want 6 known harnesses", len(rows))
	}
	var omp *Harness
	for i := range rows {
		if rows[i].ID == "omp" {
			omp = &rows[i]
		}
	}
	if omp == nil || !omp.Present {
		t.Fatalf("omp not present: %+v", rows)
	}
	// sorting puts present rows first
	if !rows[0].Present {
		t.Fatal("present rows must sort first")
	}
}
