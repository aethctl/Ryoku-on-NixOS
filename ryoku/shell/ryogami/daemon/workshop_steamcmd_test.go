package main

import (
	"strings"
	"testing"
)

func TestSteamcmdArgs(t *testing.T) {
	args := steamcmdArgs("", "/install", []string{"123"})
	joined := strings.Join(args, " ")
	for _, want := range []string{
		"+force_install_dir /install",
		"+login anonymous",
		"+workshop_download_item " + workshopAppID + " 123",
		"+quit",
	} {
		if !strings.Contains(joined, want) {
			t.Fatalf("args %q missing %q", joined, want)
		}
	}

	named := strings.Join(steamcmdArgs("bob", "", []string{"1", "2"}), " ")
	if strings.Contains(named, "force_install_dir") {
		t.Fatalf("empty install dir should be omitted: %q", named)
	}
	if !strings.Contains(named, "+login bob") {
		t.Fatalf("username not used: %q", named)
	}
	if !strings.Contains(named, "+workshop_download_item "+workshopAppID+" 1") ||
		!strings.Contains(named, "+workshop_download_item "+workshopAppID+" 2") {
		t.Fatalf("batch ids missing: %q", named)
	}
}

func TestExtractPercent(t *testing.T) {
	cases := []struct {
		line string
		want float64
		ok   bool
	}{
		{"Downloading item 123, 45%", 0.45, true},
		{"  63.5%", 0.635, true},
		{"done 100%", 1.0, true},
		{"no percent here", 0, false},
	}
	for _, tc := range cases {
		got, ok := extractPercent(tc.line)
		if ok != tc.ok {
			t.Fatalf("%q ok=%v want %v", tc.line, ok, tc.ok)
		}
		if ok && got != tc.want {
			t.Fatalf("%q got %v want %v", tc.line, got, tc.want)
		}
	}
}

func TestIsAuthError(t *testing.T) {
	if !isAuthError("ERROR! Cached credentials not found.") {
		t.Fatal("cached credentials line should be auth error")
	}
	if !isAuthError("Login Failure: Invalid Password") {
		t.Fatal("login failure line should be auth error")
	}
	if isAuthError("Success! Downloaded item.") {
		t.Fatal("success line should not be auth error")
	}
}
