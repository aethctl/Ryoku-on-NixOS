package doctor

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	i18n "ryoku-i18n"
)

// ---- reconciler: a portal frontend left over from a previous session ----------
//
// xdg-desktop-portal is only PartOf=graphical-session.target and nothing ever
// stops that target, so logging out and back in leaves the old session's
// frontend running. A ScreenCast request then times out inside it instead of
// reaching the compositor's portal backend: no source picker, and the app is
// handed nothing with no error anywhere the user looks. A frontend older than
// the session it serves cannot belong to this session, and restarting it is
// enough; the backend re-registers on demand.

// parseStartTicks reads field 22 of /proc/<pid>/stat, in clock ticks since boot.
// The comm field may itself hold spaces and parentheses, so the count starts at
// the LAST ')' instead of splitting the whole line.
func parseStartTicks(stat string) (uint64, bool) {
	paren := strings.LastIndexByte(stat, ')')
	if paren < 0 {
		return 0, false
	}
	// state (field 3) is the first field after comm, so starttime (22) is the
	// 20th of what remains.
	f := strings.Fields(stat[paren+1:])
	if len(f) < 20 {
		return 0, false
	}
	ticks, err := strconv.ParseUint(f[19], 10, 64)
	if err != nil {
		return 0, false
	}
	return ticks, true
}

func procStartTicks(pid int) (uint64, bool) {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "stat"))
	if err != nil {
		return 0, false
	}
	return parseStartTicks(string(b))
}

// sessionStartTicks is when this login session began, read from its leader
// process so the check stays compositor-neutral: a portal frontend left from a
// previous login predates this leader whatever window manager runs.
func sessionStartTicks() (uint64, bool) {
	sid := strings.TrimSpace(os.Getenv("XDG_SESSION_ID"))
	if sid == "" {
		return 0, false
	}
	out, err := exec.Command("loginctl", "show-session", sid, "-p", "Leader", "--value").Output()
	if err != nil {
		return 0, false
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(out)))
	if err != nil || pid <= 0 {
		return 0, false
	}
	return procStartTicks(pid)
}

// userUnitMainPID is the MainPID of a --user unit, or 0 when it is not running.
func userUnitMainPID(unit string) int {
	out, err := exec.Command("systemctl", "--user", "show", "-p", "MainPID", "--value", unit).Output()
	if err != nil {
		return 0
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(out)))
	if err != nil {
		return 0
	}
	return pid
}

func reconcilePortalSession(checkOnly bool) recResult {
	sessionStart, ok := sessionStartTicks()
	if !ok {
		return okRes(i18n.T("no running session to compare against"))
	}
	fePID := userUnitMainPID("xdg-desktop-portal.service")
	if fePID == 0 {
		return okRes(i18n.T("portal frontend not running; it activates fresh on first use"))
	}
	feStart, ok := procStartTicks(fePID)
	if !ok {
		return okRes(i18n.T("could not read the portal frontend's start time"))
	}
	if feStart >= sessionStart {
		return okRes(i18n.T("portal frontend belongs to this session"))
	}
	if checkOnly {
		return wouldRes(i18n.T("the portal frontend predates this login session; screen share opens no source picker and silently shares nothing")).
			withFix(i18n.T("ryoku doctor restarts xdg-desktop-portal"))
	}
	if err := exec.Command("systemctl", "--user", "restart", "xdg-desktop-portal.service").Run(); err != nil {
		return failRes(i18n.T("could not restart the portal frontend: %v"), err).
			withFix("systemctl --user restart xdg-desktop-portal.service")
	}
	return fixedRes(i18n.T("restarted the portal frontend against this session; screen share picks a source again"))
}
