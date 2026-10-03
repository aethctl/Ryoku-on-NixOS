package sys

import (
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

// Home is the user's home directory.
func Home() string {
	if h, err := os.UserHomeDir(); err == nil {
		return h
	}
	return os.Getenv("HOME")
}

// Xdg returns envVar's value, or Home()/fallback when it is unset.
func Xdg(envVar, fallback string) string {
	if v := os.Getenv(envVar); v != "" {
		return v
	}
	return filepath.Join(Home(), fallback)
}

// ConfigHome is $XDG_CONFIG_HOME (default ~/.config).
func ConfigHome() string { return Xdg("XDG_CONFIG_HOME", ".config") }

// DataDirs returns the XDG data roots in lookup order. NixOS profiles are
// included when XDG_DATA_DIRS is absent so Doctor sees desktop files, icons and
// portal metadata exposed by the active generation instead of assuming /usr.
func DataDirs() []string {
	raw := strings.TrimSpace(os.Getenv("XDG_DATA_DIRS"))
	if raw == "" {
		if NixBackend() {
			raw = strings.Join([]string{
				filepath.Join(Home(), ".local", "share"),
				filepath.Join(Home(), ".nix-profile", "share"),
				filepath.Join("/etc/profiles/per-user", os.Getenv("USER"), "share"),
				"/run/current-system/sw/share",
				"/usr/local/share",
				"/usr/share",
			}, ":")
		} else {
			raw = "/usr/local/share:/usr/share"
		}
	}
	var out []string
	seen := map[string]bool{}
	for _, dir := range strings.Split(raw, ":") {
		dir = strings.TrimSpace(dir)
		if dir == "" || seen[dir] {
			continue
		}
		seen[dir] = true
		out = append(out, dir)
	}
	return out
}

// FindData resolves a packaged data file or directory through the active XDG
// data roots. On Arch this naturally reaches /usr/share; on NixOS it reaches
// the current generation and user profiles without hard-coding store hashes.
func FindData(rel string) string {
	rel = filepath.Clean(strings.TrimPrefix(rel, "/"))
	if rel == "." || rel == "" {
		return ""
	}
	for _, root := range DataDirs() {
		p := filepath.Join(root, rel)
		if Exists(p) {
			return p
		}
	}
	return ""
}

// ProfileBinDirs lists executable roots exposed by the active profiles.
func ProfileBinDirs() []string {
	if !NixBackend() {
		return []string{"/usr/local/bin", "/usr/bin"}
	}
	return []string{
		"/run/current-system/sw/bin",
		filepath.Join("/etc/profiles/per-user", os.Getenv("USER"), "bin"),
		filepath.Join(Home(), ".nix-profile", "bin"),
		filepath.Join(Home(), ".local", "bin"),
	}
}

// StateDir is the CLI's state root, $XDG_STATE_HOME/ryoku (default
// ~/.local/state/ryoku).
func StateDir() string {
	return filepath.Join(Xdg("XDG_STATE_HOME", ".local/state"), "ryoku")
}

// IsBtrfs reports whether path lives on a btrfs filesystem.
func IsBtrfs(path string) bool {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return false
	}
	return int64(st.Type) == 0x9123683E // BTRFS_SUPER_MAGIC
}

// FreeBytes is the space available to a non-root writer under path, and whether
// the filesystem could be read at all.
func FreeBytes(path string) (uint64, bool) {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return 0, false
	}
	return st.Bavail * uint64(st.Bsize), true
}

// IsBtrfsSubvolumeRoot reports whether path is the root of a btrfs subvolume:
// those always carry inode 256.
func IsBtrfsSubvolumeRoot(path string) bool {
	var st syscall.Stat_t
	if err := syscall.Stat(path, &st); err != nil {
		return false
	}
	return st.Ino == 256
}
