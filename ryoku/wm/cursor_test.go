package wm

import "testing"

func TestResolveCursorTheme(t *testing.T) {
	cases := map[string]string{
		CursorThemeDynamic:  CursorThemeMaterial,
		"Bibata-Modern-Ice": "Bibata-Modern-Ice",
		CursorThemeMaterial: CursorThemeMaterial,
		"":                  "",
	}
	for in, want := range cases {
		if got := ResolveCursorTheme(in); got != want {
			t.Errorf("ResolveCursorTheme(%q) = %q, want %q", in, got, want)
		}
	}
}
