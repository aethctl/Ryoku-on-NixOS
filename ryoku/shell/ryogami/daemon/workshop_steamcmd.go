package main

import (
	"bufio"
	"context"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func steamcmdInstalled() bool {
	_, err := exec.LookPath("steamcmd")
	return err == nil
}

func steamcmdArgs(username, installDir string, ids []string) []string {
	var args []string
	if installDir != "" {
		args = append(args, "+force_install_dir", installDir)
	}
	args = append(args, "+login")
	if username == "" {
		args = append(args, "anonymous")
	} else {
		args = append(args, username)
	}
	for _, id := range ids {
		args = append(args, "+workshop_download_item", workshopAppID, id)
	}
	args = append(args, "+quit")
	return args
}

// Installs alongside the existing library so the result reconciles in place.
func (w *workshopLib) steamInstallRoot() string {
	we := filepath.ToSlash(w.workshopDir())
	if strings.HasSuffix(we, "steamapps/workshop/content/"+workshopAppID) {
		root := w.workshopDir()
		for i := 0; i < 4; i++ {
			root = filepath.Dir(root)
		}
		return root
	}
	return w.steamRoot()
}

func (w *workshopLib) steamcmdDownload(item, requested string) bool {
	d := w.d
	username := wkString(d.setting("steam.username"))
	installRoot := w.steamInstallRoot()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cmd := exec.CommandContext(ctx, "steamcmd", steamcmdArgs(username, installRoot, []string{item})...)
	cmd.Stdin = nil
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		d.emitWorkshopDownload(requested, "error", 0, "steamcmd output could not be read", "")
		return false
	}
	if err := cmd.Start(); err != nil {
		d.emitWorkshopDownload(requested, "error", 0, "steamcmd not found - install it, or open the item in Steam", "")
		return false
	}

	authError := false
	sc := bufio.NewScanner(stdout)
	sc.Buffer(make([]byte, 64*1024), 1024*1024)
	for sc.Scan() {
		line := sc.Text()
		if pct, ok := extractPercent(line); ok {
			msg := ""
			if item != requested {
				msg = "Downloading required Workshop item " + item
			}
			d.emitWorkshopDownload(requested, "downloading", pct, msg, "")
		}
		if isAuthError(line) {
			authError = true
		}
	}
	_ = cmd.Wait()

	dest := filepath.Join(installRoot, "steamapps", "workshop", "content", workshopAppID, item)
	reconcileWeItem(w.workshopDir(), item, dest)
	if dirExists(filepath.Join(w.workshopDir(), item)) {
		return true
	}
	if authError {
		user := username
		if user == "" {
			user = "<your-steam-username>"
		}
		d.emitWorkshopDownload(requested, "auth_error", 0,
			"Steam login required - run once in a terminal: steamcmd +login "+user+" +quit", "")
	}
	return false
}

func extractPercent(line string) (float64, bool) {
	pct := strings.IndexByte(line, '%')
	if pct < 0 {
		return 0, false
	}
	before := strings.TrimRight(line[:pct], " ")
	start := 0
	for i := len(before) - 1; i >= 0; i-- {
		c := before[i]
		if (c < '0' || c > '9') && c != '.' {
			start = i + 1
			break
		}
	}
	f, err := strconv.ParseFloat(before[start:], 64)
	if err != nil {
		return 0, false
	}
	return f / 100.0, true
}

func isAuthError(line string) bool {
	return strings.Contains(line, "Cached credentials not found") || strings.Contains(line, "Login Failure")
}
