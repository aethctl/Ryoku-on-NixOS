package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

// runAudit lays files (and an optional manifest.json) into a fresh temp dir and
// runs the static audit over it.
func runAudit(t *testing.T, files map[string]string, manifest string) auditResult {
	t.Helper()
	dir := t.TempDir()
	if manifest != "" {
		if err := os.WriteFile(filepath.Join(dir, "manifest.json"), []byte(manifest), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	for p, c := range files {
		fp := filepath.Join(dir, p)
		if err := os.MkdirAll(filepath.Dir(fp), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(fp, []byte(c), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return auditPlugin(dir, nil)
}

func hasRule(res auditResult, rule string) bool {
	for _, f := range res.Blocking {
		if f.Rule == rule {
			return true
		}
	}
	for _, f := range res.Warnings {
		if f.Rule == rule {
			return true
		}
	}
	return false
}

func ruleIsBlocking(res auditResult, rule string) bool {
	for _, f := range res.Blocking {
		if f.Rule == rule {
			return true
		}
	}
	return false
}

// TestAuditRules is the table-driven audit test: one positive fixture (the rule
// fires) and one negative fixture (it does not) for every text-based rule.
func TestAuditRules(t *testing.T) {
	const pkexecCmd = `Item { property var c: 0
  function act() { const p = Process; command: ["pkexec", "systemctl", "poweroff"] }
}`
	const pkexecManifest = `{"capabilities":{"privileged":["pkexec systemctl poweroff"]}}`
	const netManifest = `{"capabilities":{"network":["evil.example.com"]}}`

	cases := []struct {
		name     string
		rule     string
		blocking bool
		files    map[string]string
		manifest string
		want     bool
	}{
		{"escalation-sudo-pos", "escalation", true, map[string]string{"bin/x.sh": "#!/bin/sh\nsudo reboot\n"}, "", true},
		{"escalation-sudo-neg", "escalation", true, map[string]string{"bin/x.sh": "#!/bin/sh\necho hi\n"}, "", false},

		{"escalation-pkexec-pos", "escalation", true, map[string]string{"content/x.qml": pkexecCmd}, "", true},
		{"escalation-pkexec-neg", "escalation", true, map[string]string{"content/x.qml": pkexecCmd}, pkexecManifest, false},

		{"pipe-shell-pos", "pipe-shell", true, map[string]string{"bin/i.sh": "#!/bin/sh\ncurl https://x/i.sh | sh\n"}, "", true},
		{"pipe-shell-neg", "pipe-shell", true, map[string]string{"bin/i.sh": "#!/bin/sh\ncurl example > /tmp/x\n"}, "", false},

		{"internal-import-pos", "internal-import", true, map[string]string{"content/W.qml": "import shell.services\nItem {}\n"}, "", true},
		{"internal-import-neg", "internal-import", true, map[string]string{"content/W.qml": "import QtQuick\nItem {}\n"}, "", false},

		{"config-write-pos", "config-write", true, map[string]string{"content/W.qml": "property string p: \"shell.json\"\n"}, "", true},
		{"config-write-neg", "config-write", true, map[string]string{"content/W.qml": "property string p: \"data.json\"\n"}, "", false},

		{"secret-pos", "secret", true, map[string]string{"notes.txt": "token = ghp-abcdefghij0123456789\n"}, "", true},
		{"secret-neg", "secret", true, map[string]string{"notes.txt": "token = none\n"}, "", false},

		{"binary-pos", "binary", true, map[string]string{"bin/tool": "\x7fELF\x02\x01\x01\x00\x00\x00"}, "", true},
		{"binary-neg", "binary", true, map[string]string{"bin/tool": "#!/bin/sh\necho hi\n"}, "", false},

		{"undeclared-command-pos", "undeclared-command", false, map[string]string{"content/W.qml": "command: [\"foobar\", \"x\"]\n"}, "", true},
		{"undeclared-command-neg", "undeclared-command", false, map[string]string{"content/W.qml": "command: [\"nmcli\", \"x\"]\n"}, "", false},

		{"undeclared-host-pos", "undeclared-host", false, map[string]string{"content/W.qml": "x: \"https://evil.example.com/y\"\n"}, "", true},
		{"undeclared-host-neg", "undeclared-host", false, map[string]string{"content/W.qml": "x: \"https://evil.example.com/y\"\n"}, netManifest, false},

		{"dynamic-shell-pos", "dynamic-shell", false, map[string]string{"content/W.qml": "command: [\"sh\", \"-c\", \"echo \" + userInput]\n"}, "", true},
		{"dynamic-shell-neg", "dynamic-shell", false, map[string]string{"content/W.qml": "command: [\"sh\", \"-c\", \"echo hi\"]\n"}, "", false},

		{"outside-write-pos", "outside-write", false, map[string]string{"bin/x.sh": "#!/bin/sh\necho hi > ~/.config/x\n"}, "", true},
		{"outside-write-neg", "outside-write", false, map[string]string{"bin/x.sh": "#!/bin/sh\necho hi > \"$stateDir/x\"\n"}, "", false},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			res := runAudit(t, c.files, c.manifest)
			if got := hasRule(res, c.rule); got != c.want {
				t.Fatalf("rule %q present=%v want %v (blocking=%v warnings=%v)", c.rule, got, c.want, res.Blocking, res.Warnings)
			}
			if c.want && c.blocking && !ruleIsBlocking(res, c.rule) {
				t.Fatalf("rule %q should be a blocking finding", c.rule)
			}
			if c.want && !c.blocking && ruleIsBlocking(res, c.rule) {
				t.Fatalf("rule %q should be a warning, not blocking", c.rule)
			}
		})
	}
}

// TestAuditSymlink flags a symlink anywhere in the tree as a blocking finding.
func TestAuditSymlink(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "real.qml"), []byte("import QtQuick\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("real.qml", filepath.Join(dir, "link.qml")); err != nil {
		t.Skipf("symlinks unsupported here: %v", err)
	}
	res := auditPlugin(dir, nil)
	if !ruleIsBlocking(res, "symlink") {
		t.Fatalf("symlink not reported as blocking: %+v", res)
	}
}

// TestAuditLargeTree warns when the tree exceeds 20 MB.
func TestAuditLargeTree(t *testing.T) {
	dir := t.TempDir()
	big := bytes.Repeat([]byte("a"), 21*1024*1024)
	if err := os.WriteFile(filepath.Join(dir, "big.dat"), big, 0o644); err != nil {
		t.Fatal(err)
	}
	res := auditPlugin(dir, nil)
	if !hasRule(res, "large-tree") {
		t.Fatalf("large-tree not reported")
	}
	if ruleIsBlocking(res, "large-tree") {
		t.Fatalf("large-tree should be a warning")
	}
}

// TestAuditAllowDowngrade checks --allow moves a blocking rule to warnings.
func TestAuditAllowDowngrade(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "x.sh"), []byte("#!/bin/sh\nsudo reboot\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	res := auditPlugin(dir, map[string]bool{"escalation": true})
	if ruleIsBlocking(res, "escalation") {
		t.Fatalf("escalation should be downgraded by --allow")
	}
	found := false
	for _, f := range res.Warnings {
		if f.Rule == "escalation" {
			found = true
		}
	}
	if !found {
		t.Fatalf("escalation should still appear as a warning")
	}
}

// TestNewTemplateAuditsClean is the contract's requirement that the scaffold
// passes validate with zero findings.
func TestNewTemplateAuditsClean(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "demo-x")
	if err := scaffoldPlugin(dir, "demo-x", "Demo X", "QA <qa@example.com>", "topbarGlyph", true); err != nil {
		t.Fatal(err)
	}
	res := auditPlugin(dir, nil)
	if len(res.Blocking) != 0 || len(res.Warnings) != 0 {
		t.Fatalf("template not clean: blocking=%+v warnings=%+v", res.Blocking, res.Warnings)
	}
	if _, err := validateManifest(dir, reservedIDs()); err != nil {
		t.Fatalf("template manifest rejected: %v", err)
	}
}
