package doctor

import (
	"fmt"
	"os"
	"strings"

	"ryoku-cli/internal/sys"
	"ryoku-cli/internal/updater"
)

// ---- reconciler: boot guard ----------------------------------------------------
//
// reconcileBootGuard keeps ryoku-boot-guard.service enabled on a packaged box
// (the ryoku package ships the unit; enabling it here is how boxes installed
// before it get it, since doctor runs after every update) and surfaces the
// guard's last notice: an update it reverted, or a boot menu it repointed at
// the pre-update snapshot. The notice is a one-time report and is cleared
// once shown, so it never nags.
func reconcileBootGuard(checkOnly bool) recResult {
	if sys.NixBackend() {
		return okRes("boot recovery is owned by NixOS generations; the Arch boot guard is not applicable")
	}
	if sys.ResolveRepo() != "" || !sys.PkgInstalled("ryoku-desktop") {
		return okRes("not a packaged install; the boot guard watches package updates only")
	}
	if n := updater.BootNotice(); n != nil {
		msg := fmt.Sprintf("the boot guard acted on %s: %s", n.At, n.Detail)
		if !checkOnly {
			_ = sys.Sudo("rm", "-f", "/var/lib/ryoku/boot/notice.json")
		}
		return warnRes("%s", msg).withFix("see `ryoku rollback` and `ryoku status`")
	}
	if !sys.Exists("/usr/lib/systemd/system/ryoku-boot-guard.service") {
		return okRes("boot guard not shipped by this release yet")
	}
	// the session records a good boot under /var/lib/ryoku/boot, so that
	// directory must exist and take an unprivileged write (the tmpfiles entry
	// makes it 1777 and the parent 0755; an install scriptlet may have made
	// the parent 0700 first, which the same entry corrects).
	var problems []string
	if !sys.UnitEnabled("ryoku-boot-guard.service") {
		problems = append(problems, "ryoku-boot-guard.service is not enabled")
	}
	if !bootOKWritable() {
		problems = append(problems, "/var/lib/ryoku/boot does not take a session's boot record")
	}
	if len(problems) == 0 {
		return okRes("boot guard enabled")
	}
	fix := "sudo systemctl enable ryoku-boot-guard.service && sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/ryoku.conf"
	if checkOnly {
		return wouldRes("%s, so a failed update is not reverted automatically", strings.Join(problems, "; ")).withFix(fix)
	}
	if err := sys.Sudo("systemctl", "enable", "ryoku-boot-guard.service"); err != nil {
		return failRes("could not enable ryoku-boot-guard.service: %v", err).withFix(fix)
	}
	if err := sys.Sudo("systemd-tmpfiles", "--create", "/usr/lib/tmpfiles.d/ryoku.conf"); err != nil || !bootOKWritable() {
		return failRes("could not prepare /var/lib/ryoku/boot: %v", err).withFix(fix)
	}
	return fixedRes("enabled the boot guard; a packaged update that cannot boot twice is reverted")
}

// bootOKWritable reports whether this user can drop a boot record where the
// guard reads it: the directory exists, the parent is traversable, and the
// sticky world-writable bit is on.
func bootOKWritable() bool {
	st, err := os.Stat("/var/lib/ryoku/boot")
	if err != nil || !st.IsDir() {
		return false
	}
	return st.Mode().Perm()&0o002 != 0 && st.Mode()&os.ModeSticky != 0
}
