package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// checkApp maps an HTTP answer to the tri-state the dashboard draws: a 2xx is up,
// a 4xx/5xx is warn (the service answered but is unhealthy), and no answer at all
// is down.
func TestCheckApp(t *testing.T) {
	ok := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	defer ok.Close()
	if s := checkApp("h", App{Name: "svc", URL: ok.URL}, 3*time.Second); s.State != "up" || s.Code != 200 {
		t.Fatalf("reachable 200: want up/200, got %s/%d", s.State, s.Code)
	}

	bad := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(503)
	}))
	defer bad.Close()
	if s := checkApp("h", App{Name: "svc", URL: bad.URL}, 3*time.Second); s.State != "warn" || s.Code != 503 {
		t.Fatalf("answering 503: want warn/503, got %s/%d", s.State, s.Code)
	}

	gone := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	url := gone.URL
	gone.Close()
	if s := checkApp("h", App{Name: "svc", URL: url}, time.Second); s.State != "down" {
		t.Fatalf("unreachable: want down, got %s", s.State)
	}
}

// pveGuests turns /cluster/resources into the guest list the panel shows: qemu
// and lxc only (node/storage rows dropped), sorted by vmid, with the API token
// carried in the header, never the URL.
func TestPveGuests(t *testing.T) {
	const body = `{"data":[
		{"vmid":200,"name":"ct","status":"running","node":"pve","type":"lxc","cpu":0.1,"mem":100,"maxmem":1000,"uptime":50},
		{"vmid":100,"name":"vm","status":"stopped","node":"pve","type":"qemu","maxmem":2000},
		{"id":"node/pve","node":"pve","type":"node"},
		{"id":"storage/local","type":"storage"}
	]}`
	var gotAuth, gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth, gotPath = r.Header.Get("Authorization"), r.URL.Path
		w.Write([]byte(body))
	}))
	defer srv.Close()

	g, err := pveGuests(PVE{URL: srv.URL, Token: "ryoport@pve!hub=secret"})
	if err != nil {
		t.Fatal(err)
	}
	if len(g) != 2 {
		t.Fatalf("want 2 guests (node+storage dropped), got %d", len(g))
	}
	if g[0].VMID != 100 || g[1].VMID != 200 {
		t.Fatalf("want vmid-sorted 100,200, got %d,%d", g[0].VMID, g[1].VMID)
	}
	if g[0].Type != "qemu" || g[1].Type != "lxc" {
		t.Fatalf("types wrong: %s,%s", g[0].Type, g[1].Type)
	}
	if gotAuth != "PVEAPIToken=ryoport@pve!hub=secret" {
		t.Fatalf("auth header wrong: %q", gotAuth)
	}
	if gotPath != "/api2/json/cluster/resources" {
		t.Fatalf("path wrong: %q", gotPath)
	}
}

// pveAction posts to the guest's status endpoint on its owning node.
func TestPveAction(t *testing.T) {
	var gotMethod, gotPath, gotAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotMethod, gotPath, gotAuth = r.Method, r.URL.Path, r.Header.Get("Authorization")
		w.Write([]byte(`{"data":"UPID:pve:0"}`))
	}))
	defer srv.Close()

	if err := pveAction(PVE{URL: srv.URL, Token: "u@pam!t=s"}, "pve", "qemu", "100", "start"); err != nil {
		t.Fatal(err)
	}
	if gotMethod != http.MethodPost {
		t.Fatalf("want POST, got %s", gotMethod)
	}
	if gotPath != "/api2/json/nodes/pve/qemu/100/status/start" {
		t.Fatalf("path wrong: %s", gotPath)
	}
	if gotAuth != "PVEAPIToken=u@pam!t=s" {
		t.Fatalf("auth wrong: %s", gotAuth)
	}
}

// pveValidNode keeps a crafted node segment from reshaping the request path.
func TestPveValidNode(t *testing.T) {
	for _, ok := range []string{"pve", "pve-1", "node.dc1", "n_2"} {
		if !pveValidNode(ok) {
			t.Fatalf("%q should be valid", ok)
		}
	}
	for _, bad := range []string{"", "pve/..", "a b", "n;rm", "../x"} {
		if pveValidNode(bad) {
			t.Fatalf("%q should be rejected", bad)
		}
	}
}

// Ghostty rejects `--class NAME` (its CLI wants `--class=NAME`) and validates the
// value as a GTK application id, which needs a dot: a bare "ryoport-ssh" was
// dropped on the floor, the window kept com.mitchellh.ghostty, and the float
// window rule never matched (issue #280). Every terminal on the switch now gets
// the equals form and the same GTK-valid id.
func TestTerminalArgvClassForm(t *testing.T) {
	if !strings.Contains(ryoportAppID, ".") || strings.Contains(ryoportAppID, "-") {
		t.Fatalf("%q is not a GTK application id (needs a dot, hyphens are rejected)", ryoportAppID)
	}
	for _, term := range []string{"kitty", "ghostty", "foot", "alacritty"} {
		t.Setenv("TERMINAL", term)
		argv := terminalArgv("myhost")
		var hasID, hasBare bool
		for _, a := range argv {
			if strings.HasSuffix(a, "="+ryoportAppID) {
				hasID = true // --class=<id>, or --app-id=<id> on foot
			}
			if a == "--class" || a == "--app-id" {
				hasBare = true
			}
		}
		if !hasID {
			t.Errorf("%s argv = %v, want the GTK id %q passed with =", term, argv, ryoportAppID)
		}
		if hasBare {
			t.Errorf("%s argv = %v, must not pass a valueless class flag", term, argv)
		}
	}
	// wezterm and xterm take no class at all: they must not gain one either way.
	t.Setenv("TERMINAL", "wezterm")
	for _, a := range terminalArgv("myhost") {
		if strings.HasPrefix(a, "--class") {
			t.Fatalf("wezterm argv carries a class flag: %v", a)
		}
	}
}
