package main

type appChoice struct {
	ID       string
	Label    string
	Detail   string
	Category string
}

func optionalApps() []appChoice {
	return []appChoice{
		{ID: "prompt", Label: "Starship", Detail: "cross-shell Ryoku prompt", Category: "TERMINAL"},
		{ID: "bash-edit", Label: "Blesh", Detail: "Bash line editing extras", Category: "TERMINAL"},
		{ID: "fastfetch", Label: "Fastfetch", Detail: "terminal system readout", Category: "TERMINAL"},
		{ID: "yazi", Label: "Yazi", Detail: "terminal file manager", Category: "TERMINAL"},
		{ID: "cli-tools", Label: "Modern CLI tools", Detail: "eza · bat · fzf · zoxide", Category: "TERMINAL"},
		{ID: "git-tools", Label: "Lazygit", Detail: "interactive Git client; gh is already in Ryoku", Category: "TERMINAL"},
		{ID: "pavucontrol", Label: "PulseAudio Volume Control", Detail: "advanced PipeWire/PulseAudio mixer", Category: "MEDIA & TOOLS"},
		{ID: "songrec", Label: "SongRec", Detail: "identify playing music", Category: "MEDIA & TOOLS"},
		{ID: "openrgb", Label: "OpenRGB", Detail: "RGB device control", Category: "MEDIA & TOOLS"},
		{ID: "upscale", Label: "Image upscaler", Detail: "waifu2x Vulkan runtime", Category: "MEDIA & TOOLS"},
		{ID: "localsend", Label: "LocalSend", Detail: "local-network file transfer app", Category: "MEDIA & TOOLS"},
		{ID: "gamescope", Label: "Gamescope", Detail: "gaming compositor", Category: "GAMING"},
		{ID: "gamemode", Label: "GameMode", Detail: "temporary game performance tuning", Category: "GAMING"},
		{ID: "mangohud", Label: "MangoHud", Detail: "performance overlay", Category: "GAMING"},
		{ID: "vm", Label: "Virtual machines", Detail: "Quickemu · QEMU · SPICE", Category: "SYSTEM"},
		{ID: "docker", Label: "Docker", Detail: "declarative daemon, lazy on boot", Category: "SYSTEM"},
		{ID: "flatpak", Label: "Flatpak", Detail: "declarative Flatpak service", Category: "SYSTEM"},
		{ID: "go", Label: "Go", Detail: "Go toolchain", Category: "DEVELOPER"},
		{ID: "pytools", Label: "pipx", Detail: "isolated Python CLI applications", Category: "DEVELOPER"},
		{ID: "mise", Label: "mise", Detail: "language/runtime version manager", Category: "DEVELOPER"},
	}
}

func requiredApps() []string {
	return []string{
		"Kitty terminal", "Files (Nautilus)", "Neovim", "btop",
		"Fish runtime", "Node.js", "Python", "Ryoku desktop services",
	}
}
