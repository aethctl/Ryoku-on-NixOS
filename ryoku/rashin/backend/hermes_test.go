package main

import (
	"os"
	"path/filepath"
	"testing"
)

func writeHermesConfig(t *testing.T, content string) {
	t.Helper()
	dir := filepath.Join(home(), ".hermes")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "config.yaml"), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestHermesOnboardedTemplateIsNotConfigured(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	if hermesOnboarded() {
		t.Fatal("missing config.yaml must not count as onboarded")
	}
	// The installer's template: a model key with no value.
	writeHermesConfig(t, "# hermes config\nmodel:\nterminal:\n  backend: local\n")
	if hermesOnboarded() {
		t.Fatal("template config with empty model must not count as onboarded")
	}
}

func TestHermesOnboardedChosenModelIsConfigured(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	writeHermesConfig(t, "model: openrouter/anthropic/claude-sonnet-4.5\n")
	if !hermesOnboarded() {
		t.Fatal("a chosen model means onboarding happened")
	}
}

func TestHermesOnboardedMappingForm(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	writeHermesConfig(t, "model:\n  provider: openai-codex\n  base_url: https://x\n  default: gpt-5.5\nterminal:\n  backend: local\n")
	if !hermesOnboarded() {
		t.Fatal("mapping-form model must count as onboarded")
	}
	p, m, ok := hermesModel()
	if !ok || p != "openai-codex" || m != "gpt-5.5" {
		t.Fatalf("hermesModel = %q %q %v", p, m, ok)
	}
}

func TestHermesModelStopsAtBlockEnd(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	writeHermesConfig(t, "model:\nterminal:\n  backend: local\n  provider: bogus\n")
	if hermesOnboarded() {
		t.Fatal("empty mapping followed by another block must not count")
	}
}

func TestSavedSessionModelFollowsHermesConfig(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("RYOKU_STATE_PATH", t.TempDir())
	writeHermesConfig(t, "model:\n  provider: openrouter\n  default: z-ai/glm-5.3\n")
	saveSessionModel("openrouter:z-ai/glm-5.3")
	if got := savedSessionModel(); got != "openrouter:z-ai/glm-5.3" {
		t.Fatalf("pick under the same config = %q", got)
	}
	// The user ran `hermes setup` again and chose another provider: the old
	// pick must not be re-applied on the new endpoint.
	writeHermesConfig(t, "model:\n  provider: nvidia\n  default: meta/llama-3.3-70b-instruct\n")
	if got := savedSessionModel(); got != "" {
		t.Fatalf("pick survived a reconfigure: %q", got)
	}
}

func TestSavedSessionModelWithoutFingerprintIsForgotten(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("RYOKU_STATE_PATH", t.TempDir())
	writeHermesConfig(t, "model: openrouter/anthropic/claude-sonnet-4.5\n")
	if err := os.WriteFile(modelStatePath(), []byte("openrouter:z-ai/glm-5.3\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := savedSessionModel(); got != "" {
		t.Fatalf("a pick from before the fingerprint must not be trusted: %q", got)
	}
}
