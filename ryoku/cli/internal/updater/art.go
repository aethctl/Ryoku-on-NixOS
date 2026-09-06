package updater

import (
	"embed"
	"strings"
)

//go:embed art/*.txt
var artFS embed.FS

func releaseArt(name string) string {
	b, err := artFS.ReadFile("art/" + strings.ToLower(name) + ".txt")
	if err != nil {
		return ""
	}
	return string(b)
}
