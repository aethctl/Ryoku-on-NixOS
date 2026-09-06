package sys

import (
	"os"
	"path/filepath"
	"testing"
)

func TestChannelServerRoundTrips(t *testing.T) {
	for _, ch := range []string{"stable", "testing", "v0.55.7-beta.19", "v1.0.0", "v1.2.3-rc.1"} {
		srv := ChannelServer(ch)
		if srv == "" {
			t.Fatalf("%s: no server", ch)
		}
		if got := ChannelOfServer(srv); got != ch {
			t.Fatalf("%s -> %s -> %q", ch, srv, got)
		}
	}
	if ChannelServer("main") != "" || ChannelServer("v1") != "" || ChannelServer("releases/v1.0.0") != "" ||
		ChannelServer("v0.56.0-beta.19.dev.363+g4d1cf63") != "" {
		t.Fatal("non-channels must not map to a server")
	}
}

func TestChannelOfServerAcceptsWhatBoxesCarry(t *testing.T) {
	cases := map[string]string{
		"https://repo.ryoku.dev/stable/$arch":                            "stable",
		"https://repo.ryoku.dev/stable/x86_64":                           "stable",
		"https://repo.ryoku.dev/stable/x86_64/":                          "stable",
		"https://repo.ryoku.dev/stable/channels/testing/$arch":           "testing",
		"https://repo.ryoku.dev/stable/releases/v0.55.7-beta.19/$arch":   "v0.55.7-beta.19",
		"https://repo.ryoku.dev/stable/releases/v0.55.7-beta.19/x86_64/": "v0.55.7-beta.19",
		"file:///home/x/ryoku-arch/release/repo/out/$arch":               "",
		"https://mirror.example.org/ryoku/$arch":                         "",
		"https://repo.ryoku.dev/stable/releases/not-a-tag/$arch":         "",
	}
	for in, want := range cases {
		if got := ChannelOfServer(in); got != want {
			t.Errorf("%s: got %q want %q", in, got, want)
		}
	}
}

func TestRyokuServerReadsTheStanza(t *testing.T) {
	dir := t.TempDir()
	conf := filepath.Join(dir, "pacman.conf")
	os.WriteFile(conf, []byte("[options]\nHoldPkg = pacman\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[ryoku]\nSigLevel = Required\nServer = https://repo.ryoku.dev/stable/$arch\n\n[extra]\nServer = https://example/$arch\n"), 0o644)
	old := PacmanConf
	PacmanConf = conf
	defer func() { PacmanConf = old }()
	if got := RyokuServer(); got != "https://repo.ryoku.dev/stable/$arch" {
		t.Fatalf("server = %q", got)
	}
	if got := PackagedChannel(); got != "stable" {
		t.Fatalf("channel = %q", got)
	}
}

func TestReadReleaseParsesTheMarker(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "ryoku-release")
	os.WriteFile(f, []byte("RELEASE=v0.55.7-beta.19\nNAME=Onogoro\nCHANNEL=stable\nVERSION=0.55.7.r3280.g097f522\nCOMMIT=097f522b5\nDATE=2026-09-03T20:00:00Z\n"), 0o644)
	old := ReleaseFile
	ReleaseFile = f
	defer func() { ReleaseFile = old }()
	r := ReadRelease()
	if r.Release != "v0.55.7-beta.19" || r.Name != "Onogoro" || r.Channel != "stable" || r.Version != "0.55.7.r3280.g097f522" || r.Commit != "097f522b5" {
		t.Fatalf("release = %+v", r)
	}
	ReleaseFile = filepath.Join(dir, "missing")
	if r := ReadRelease(); r.Release != "" {
		t.Fatalf("missing file must read empty, got %+v", r)
	}
}
