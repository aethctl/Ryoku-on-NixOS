package doctor

import (
	"os"
	"path/filepath"
	"strings"

	"ryoku-cli/internal/sys"
)

// Packages the doctor installs on its own (a client spicetify can patch, the
// ASUS daemon) are recorded here, so a package it provisioned once and the
// user then removed stays removed: an update must not put back what someone
// took away. Deleting a name from the file lets the doctor provision it again.
var provisionedFile = func() string {
	return filepath.Join(sys.StateDir(), "provisioned")
}

func provisioned() map[string]bool {
	out := map[string]bool{}
	b, err := os.ReadFile(provisionedFile())
	if err != nil {
		return out
	}
	for _, ln := range strings.Split(string(b), "\n") {
		if ln = strings.TrimSpace(ln); ln != "" {
			out[ln] = true
		}
	}
	return out
}

func recordProvisioned(pkg string) {
	if provisioned()[pkg] {
		return
	}
	path := provisionedFile()
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.WriteString(pkg + "\n")
}

// removedByUser reports whether pkg was provisioned by the doctor before and
// is gone now, which only a deliberate removal explains.
func removedByUser(pkg string) bool {
	return provisioned()[pkg] && !sys.PkgInstalled(pkg)
}

// provision installs pkg through install unless the user removed it after an
// earlier provisioning. It returns whether the install landed and whether it
// was skipped for that reason.
func provision(pkg string, install func() bool) (present, skipped bool) {
	if removedByUser(pkg) {
		return false, true
	}
	if !install() {
		return false, false
	}
	recordProvisioned(pkg)
	return true, false
}
