package updater

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"ryoku-cli/internal/sys"
)

// channelRelease is release.json as build-repo.sh writes it beside a channel's
// db: which release that channel serves right now.
type channelRelease struct {
	Release string `json:"release"`
	Name    string `json:"name"`
	Channel string `json:"channel"`
	Version string `json:"version"`
	Commit  string `json:"commit"`
	Date    string `json:"date"`
}

// releaseLedger is releases/index.json, the list publish-repo.yml appends a
// stable release to; `ryoku rollback` offers its entries.
type releaseLedger struct {
	Latest   string          `json:"latest"`
	Releases []ledgerRelease `json:"releases"`
}

type ledgerRelease struct {
	Tag     string `json:"tag"`
	Name    string `json:"name"`
	Version string `json:"version"`
	Commit  string `json:"commit"`
	Date    string `json:"date"`
	Repo    string `json:"repo"`
}

// releaseFetchTTL bounds how often `ryoku status` (polled by the Hub and the
// update island) re-reads a channel's release.json.
const releaseFetchTTL = 10 * time.Minute

// RYOKU_RELEASE_BASE overrides RepoBase for tests and a local mirror.
func repoBase() string {
	if b := strings.TrimSpace(os.Getenv("RYOKU_RELEASE_BASE")); b != "" {
		return strings.TrimSuffix(b, "/")
	}
	return sys.RepoBase
}

// fetchCached GETs url into a state-dir cache keyed by name, re-fetching
// after ttl; offline or on error it serves the last cached body, or nil.
func fetchCached(name, url string, ttl time.Duration) []byte {
	dir := filepath.Join(sys.StateDir(), "release-cache")
	path := filepath.Join(dir, name)
	if st, err := os.Stat(path); err == nil && time.Since(st.ModTime()) < ttl {
		if b, err := os.ReadFile(path); err == nil {
			return b
		}
	}
	client := &http.Client{Timeout: 6 * time.Second}
	resp, err := client.Get(url)
	if err == nil {
		defer resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			if b, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20)); err == nil {
				_ = os.MkdirAll(dir, 0o755)
				_ = os.WriteFile(path, b, 0o644)
				return b
			}
		}
	}
	if b, err := os.ReadFile(path); err == nil {
		return b
	}
	return nil
}

// channelServes reads what a channel currently serves, or a zero value when
// the channel is unreachable and nothing is cached.
func channelServes(channel string) channelRelease {
	var r channelRelease
	url := strings.Replace(sys.ChannelServer(channel), sys.RepoBase, repoBase(), 1)
	url = strings.Replace(url, "$arch", "x86_64", 1)
	if url == "" {
		return r
	}
	if b := fetchCached("channel-"+sanitize(channel)+".json", url+"/release.json", releaseFetchTTL); b != nil {
		_ = json.Unmarshal(b, &r)
	}
	return r
}

// ledger reads the release ledger, newest first.
func ledger() releaseLedger {
	var l releaseLedger
	if b := fetchCached("releases-index.json", repoBase()+"/releases/index.json", releaseFetchTTL); b != nil {
		_ = json.Unmarshal(b, &l)
	}
	return l
}

func sanitize(s string) string {
	return strings.Map(func(r rune) rune {
		if r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '.' || r == '-' {
			return r
		}
		return '_'
	}, s)
}

// Track moves a packaged box between package channels: stable (the pointer
// every install starts on), testing (rebuilt on every push to unstable-dev),
// or a release tag (pinned to that frozen release until tracked away). It
// rewrites the [ryoku] Server line and runs an update, which moves the Ryoku
// set to whatever the channel serves, down as well as up. A checkout box
// tracks git branches instead; that path stays in bin/ryoku-track.
func Track(channel string) error {
	if sys.ResolveRepo() != "" {
		return fmt.Errorf("this box runs from a checkout; package channels apply to packaged installs (use `ryoku track main|unstable-dev` here)")
	}
	if !sys.PkgInstalled("ryoku-desktop") {
		return fmt.Errorf("ryoku-desktop is not installed; nothing to track")
	}
	if sys.ChannelServer(channel) == "" {
		return fmt.Errorf("unknown channel %q: stable, testing, or a release tag (see `ryoku rollback` for the list)", channel)
	}
	cur := sys.PackagedChannel()
	if cur == channel {
		if serves := channelServes(channel).Release; serves == "" || serves == sys.ReadRelease().Release {
			fmt.Printf("already on %s\n", channel)
			return nil
		}
		fmt.Printf("==> Already tracking %s; moving the Ryoku set to what it serves\n", channel)
		return Update([]string{"--channel-switch"})
	}
	if cur == "" && sys.RyokuServer() != "" {
		return fmt.Errorf("the [ryoku] repo points at %s, a mirror Ryoku does not publish; edit /etc/pacman.conf by hand", sys.RyokuServer())
	}
	if err := sys.SetPackagedChannel(channel); err != nil {
		return err
	}
	switch {
	case channel == sys.ChannelTesting:
		fmt.Println("==> Now tracking testing: every push to unstable-dev, before it is released. Expect breakage; `ryoku track stable` returns.")
	case sys.IsReleaseTag(channel):
		fmt.Printf("==> Pinned to release %s. `ryoku update` keeps this release; `ryoku track stable` follows releases again.\n", channel)
	default:
		fmt.Println("==> Now tracking stable: named releases as they are published.")
	}
	return Update([]string{"--channel-switch"})
}
