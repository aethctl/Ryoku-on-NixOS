package main

// sessionEntry is the wayland-session .desktop the installer writes as a
// fallback when the niri package shipped none. Byte-identical to the entry
// niri itself installs, DesktopNames included: that is what sets
// XDG_CURRENT_DESKTOP, which is how the seam detects the provider when no
// socket handle is exported yet.
const sessionEntry = `[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri`

// runSession prints the wayland-session entry. It must work with no live
// compositor: the installer writes the file inside a chroot.
func runSession() error {
	_, err := stdout.WriteString(sessionEntry + "\n")
	return err
}
