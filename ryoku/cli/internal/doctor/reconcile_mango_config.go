package doctor

import (
	"os/exec"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"strings"

	i18n "ryoku-i18n"
	wm "ryoku-wm"
)

// ---- reconciler: mango config integrity --------------------------------------
//
// reconcileMangoConfig validates the config the session will read, the way
// mango itself reads it: `mango -c <entry> -p` parses the whole sourced tree
// and exits nonzero on a bad line. Unlike niri, a missing source is only an
// error LOG line and the validator passes, so there is no "not applied yet"
// state to excuse: a tree that fails -p is a tree the session will reject at
// the first real setting, and the repair is the same as everywhere else in
// doctor: re-author the provider's generated files from the neutral store,
// then validate again.

func reconcileMangoConfig(checkOnly bool) recResult {
	if wm.Detect().Name != wm.ProviderMango {
		return okRes(i18n.T("no mango session"))
	}
	entry := filepath.Join(sys.ConfigHome(), wm.ConfigEntry(wm.ProviderMango))
	if !sys.Exists(entry) {
		return okRes(i18n.T("no mango config present"))
	}
	if _, err := exec.LookPath("mango"); err != nil {
		return noteRes(i18n.T("mango config not checked (mango is not on PATH)"))
	}
	failure := func(out []byte) string {
		for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			if strings.Contains(line, "ERROR") {
				return strings.TrimSpace(line)
			}
		}
		first := strings.TrimSpace(string(out))
		if i := strings.IndexByte(first, '\n'); i >= 0 {
			first = first[:i]
		}
		return first
	}
	out, err := exec.Command("mango", "-c", entry, "-p").CombinedOutput()
	if err == nil {
		return okRes(i18n.T("mango config loads cleanly"))
	}
	if checkOnly {
		return warnRes(i18n.T("mango config does not load: %s"), failure(out)).
			withFix(i18n.T("ryoku doctor"))
	}
	store := filepath.Join(sys.ConfigHome(), "ryoku", "desktop.json")
	if _, err := wm.Open().Apply(store); err != nil {
		return failRes(i18n.T("mango config does not load and re-applying the settings failed: %v"), err)
	}
	if out, err := exec.Command("mango", "-c", entry, "-p").CombinedOutput(); err != nil {
		return failRes(i18n.T("mango config still does not load: %s"), failure(out)).
			withFix(i18n.T("fix %s by hand"), entry)
	}
	return fixedRes(i18n.T("re-authored the mango config; it loads cleanly again"))
}
