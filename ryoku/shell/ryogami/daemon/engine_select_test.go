package main

import "testing"

func TestDesiredEngine(t *testing.T) {
	cases := []struct {
		paper, video string
		isVideo      bool
		want         string
	}{
		{"shell", "ryogami", false, "shell"},
		{"skwd-paper", "ryogami", false, "skwd-paper"},
		{"awww", "ryogami", false, "awww"},
		{"shell", "ryogami", true, "shell"},
		{"shell", "in_shell", true, "shell"},
		{"shell", "vulkan", true, "skwd-paper"},
		{"skwd-paper", "ryogami", true, "skwd-paper"},
		{"awww", "ryogami", true, "shell"},
		{"awww", "vulkan", true, "skwd-paper"},
	}
	for _, c := range cases {
		if got := desiredEngine(c.paper, c.video, c.isVideo); got != c.want {
			t.Errorf("desiredEngine(%q,%q,video=%v)=%q want %q", c.paper, c.video, c.isVideo, got, c.want)
		}
	}
}

func TestConfiguredGpuDevice(t *testing.T) {
	cases := map[string]string{
		"uuid:ABCDEF0123456789ABCDEF0123456789": "uuid:abcdef0123456789abcdef0123456789",
		"auto":                                  "auto",
		"uuid:bad":                              "auto",
		"uuid:gggggggggggggggggggggggggggggggg": "auto",
		"0":                                     "auto",
		"Integrated GPU":                        "auto",
		"":                                      "auto",
	}
	for in, want := range cases {
		if got := configuredGpuDevice(in); got != want {
			t.Errorf("configuredGpuDevice(%q)=%q want %q", in, got, want)
		}
	}
}
