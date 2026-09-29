package main

// prowlapi.go makes rashin the one HTTP surface for Prowl's code intelligence
// and provider directory. Prowl ships `prowl api`, a loopback JSON server over
// its index; rashin ensures it is up (spawning it lazily against the repo
// prowlRepo() names), authenticates with the machine-local gateway token the
// two tools already share, and proxies GET /api/code/* and GET /api/providers.
// When prowl is absent or the api cannot start, every caller gets an honest
// degraded report rather than a fabricated answer, so the dashboard never
// shows a dead panel as an empty one.

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

const prowlAPIPort = 8787

func prowlAPIPortNo() int {
	if v := os.Getenv("RYOKU_PROWL_API_PORT"); v != "" {
		if n := atoiOr(v, 0); n > 0 {
			return n
		}
	}
	return prowlAPIPort
}

func prowlAPIBase() string {
	return "http://127.0.0.1:" + itoa(prowlAPIPortNo())
}

func atoiOr(s string, fallback int) int {
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			return fallback
		}
		n = n*10 + int(c-'0')
	}
	if n == 0 {
		return fallback
	}
	return n
}

// prowlAPIToken reads the machine-local gateway token prowl wrote when it
// first came up. rashin never creates it: ensure-idempotent spawning runs
// `prowl api`, which calls EnsureToken itself, so the file exists by the time
// the server answers on the port.
func prowlAPIToken() string {
	base := os.Getenv("XDG_DATA_HOME")
	if base == "" {
		base = filepath.Join(home(), ".local", "share")
	}
	for _, name := range []string{"prowl-agent", "prowl"} {
		b, err := os.ReadFile(filepath.Join(base, name, "gateway", "token"))
		if err == nil && strings.TrimSpace(string(b)) != "" {
			return strings.TrimSpace(string(b))
		}
	}
	return ""
}

var prowlAPI struct {
	mu      sync.Mutex
	spawned time.Time
	ok      bool
	err     string
}

// ensureProwlAPI probes health; on a miss it spawns `prowl api --repo <repo>`
// detached and waits up to 20s for it to answer (first open may index).
// Failures are remembered briefly so a broken prowl does not respawn per
// dashboard poll.
func ensureProwlAPI() error {
	prowlAPI.mu.Lock()
	defer prowlAPI.mu.Unlock()
	if prowlAPIHealthy() {
		prowlAPI.ok, prowlAPI.err = true, ""
		return nil
	}
	if !prowlAPI.ok && prowlAPI.err != "" && time.Since(prowlAPI.spawned) < 2*time.Minute {
		return &prowlAPIFailure{prowlAPI.err}
	}
	bin, found := findProwl()
	if !found {
		prowlAPI.err = "prowl is not installed"
		prowlAPI.spawned = time.Now()
		return &prowlAPIFailure{prowlAPI.err}
	}
	repo := prowlRepo()
	if repo == "" {
		prowlAPI.err = "no indexed project for prowl to serve"
		prowlAPI.spawned = time.Now()
		return &prowlAPIFailure{prowlAPI.err}
	}
	cmd := exec.Command(bin, "api", "--repo", repo, "--port", itoa(prowlAPIPortNo()))
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdout, cmd.Stderr = nil, nil
	if err := cmd.Start(); err != nil {
		prowlAPI.err = "spawn prowl api: " + err.Error()
		prowlAPI.spawned = time.Now()
		return &prowlAPIFailure{prowlAPI.err}
	}
	go func() { _ = cmd.Wait() }()
	deadline := time.Now().Add(20 * time.Second)
	for time.Now().Before(deadline) {
		time.Sleep(500 * time.Millisecond)
		if prowlAPIHealthy() {
			prowlAPI.ok, prowlAPI.err = true, ""
			return nil
		}
	}
	prowlAPI.err = "prowl api did not come up within 20s"
	prowlAPI.spawned = time.Now()
	return &prowlAPIFailure{prowlAPI.err}
}

type prowlAPIFailure struct{ msg string }

func (e *prowlAPIFailure) Error() string { return e.msg }

func prowlAPIHealthy() bool {
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(prowlAPIBase() + "/health")
	if err != nil {
		return false
	}
	defer func() { _ = resp.Body.Close() }()
	return resp.StatusCode == http.StatusOK
}

// prowlAPIGet proxies one authenticated GET to the prowl api and returns the
// raw JSON body. Non-2xx bodies are prowl's {"error": ...} shape and returned
// verbatim with an error, so the caller can pass them through.
func prowlAPIGet(pathAndQuery string) ([]byte, error) {
	if err := ensureProwlAPI(); err != nil {
		return nil, err
	}
	req, err := http.NewRequest(http.MethodGet, prowlAPIBase()+pathAndQuery, nil)
	if err != nil {
		return nil, err
	}
	if tok := prowlAPIToken(); tok != "" {
		req.Header.Set("Authorization", "Bearer "+tok)
	}
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= 400 {
		return body, &prowlAPIFailure{strings.TrimSpace(decodeAPIError(body))}
	}
	return body, nil
}

func decodeAPIError(body []byte) string {
	var doc struct {
		Error string `json:"error"`
	}
	if json.Unmarshal(body, &doc) == nil && doc.Error != "" {
		return doc.Error
	}
	return string(body)
}

// prowlAPIStatus is the degraded-visibility shape the dashboard polls before
// rendering code panels: installed/serving/repo/error, never a guess.
func prowlAPIStatus() map[string]any {
	_, found := findProwl()
	out := map[string]any{"installed": found}
	if found {
		if v, err := prowlExec("", 4*time.Second, "version"); err == nil {
			out["version"] = strings.TrimSpace(firstLine(string(v)))
		}
	}
	out["repo"] = prowlRepo()
	if !found {
		out["serving"] = false
		out["error"] = "prowl is not installed"
		return out
	}
	if prowlAPIHealthy() {
		out["serving"] = true
		return out
	}
	if err := ensureProwlAPI(); err != nil {
		out["serving"] = false
		out["error"] = err.Error()
		return out
	}
	out["serving"] = true
	return out
}
