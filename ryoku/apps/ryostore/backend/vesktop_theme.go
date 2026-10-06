package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func validVesktopThemeName(name string) bool {
	if !validProductPath(name) || filepath.Base(name) != name ||
		!strings.HasSuffix(name, ".theme.css") || len(name) <= len(".theme.css") {
		return false
	}
	first := name[0]
	if !(first >= 'a' && first <= 'z' || first >= 'A' && first <= 'Z' || first >= '0' && first <= '9') {
		return false
	}
	for _, char := range name {
		if char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z' ||
			char >= '0' && char <= '9' || char == '.' || char == '-' || char == '_' {
			continue
		}
		return false
	}
	return true
}

func vesktopThemeManifestFile(files []ProductFile) (string, error) {
	name := ""
	for _, file := range files {
		if !file.Install {
			continue
		}
		if name != "" || !validVesktopThemeName(file.Destination) || file.Mode != "0644" {
			return "", fmt.Errorf("Vesktop theme must install one flat .theme.css file")
		}
		name = file.Destination
	}
	if name == "" {
		return "", fmt.Errorf("Vesktop theme has no installable CSS")
	}
	return name, nil
}

func vesktopThemeReceiptFile(files []ReceiptFile) (string, error) {
	if len(files) != 1 || !validVesktopThemeName(files[0].Destination) || files[0].Mode != "0644" {
		return "", fmt.Errorf("Vesktop theme receipt must own one flat .theme.css file")
	}
	return files[0].Destination, nil
}

func syncVesktopTheme(journal productTransactionJournal, committed bool) error {
	oldName := ""
	if journal.PriorReceipt != nil {
		var err error
		oldName, err = vesktopThemeReceiptFile(journal.PriorReceipt.Files)
		if err != nil {
			return err
		}
	}
	newName := journal.VesktopThemeFile
	desired := oldName
	if committed {
		if journal.Operation == "remove" {
			desired = ""
		} else {
			desired = newName
		}
	}
	dst, _, err := productDestination(vesktopThemesCategory, journal.ID)
	if err != nil {
		return err
	}
	if committed && journal.Operation != "remove" {
		receipt, err := readReceipt(vesktopThemesCategory, journal.ID)
		if err != nil {
			return err
		}
		name, err := vesktopThemeReceiptFile(receipt.Files)
		if err != nil || name != newName {
			return fmt.Errorf("Vesktop theme journal does not match its receipt")
		}
	}
	themesDir := filepath.Join(configHome(), "vesktop", "themes")
	if err := rejectSymlinkPath(configHome(), filepath.Join("vesktop", "themes")); err != nil {
		return err
	}
	for _, name := range []string{oldName, newName} {
		if name == "" || name == desired {
			continue
		}
		if err := removeVesktopThemeLink(filepath.Join(themesDir, name), filepath.Join(dst, name), committed); err != nil {
			return err
		}
	}
	if desired == "" {
		return nil
	}
	source, err := filepath.Abs(filepath.Join(dst, desired))
	if err != nil {
		return err
	}
	info, err := os.Lstat(source)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("Vesktop theme source is not a regular file: %s", source)
	}
	if err := os.MkdirAll(themesDir, 0o755); err != nil {
		return err
	}
	link := filepath.Join(themesDir, desired)
	info, err = os.Lstat(link)
	if err == nil {
		if info.Mode()&os.ModeSymlink == 0 {
			return fmt.Errorf("refusing to replace unmanaged Vesktop theme %s", link)
		}
		current, err := os.Readlink(link)
		if err != nil {
			return err
		}
		if current != source {
			return fmt.Errorf("refusing to replace unmanaged Vesktop theme %s", link)
		}
		return nil
	}
	if !os.IsNotExist(err) {
		return err
	}
	return os.Symlink(source, link)
}

func removeVesktopThemeLink(link, source string, strict bool) error {
	info, err := os.Lstat(link)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink == 0 {
		if strict {
			return fmt.Errorf("refusing to remove unmanaged Vesktop theme %s", link)
		}
		return nil
	}
	current, err := os.Readlink(link)
	if err != nil {
		return err
	}
	expected, err := filepath.Abs(source)
	if err != nil {
		return err
	}
	if current != expected {
		if strict {
			return fmt.Errorf("refusing to remove unmanaged Vesktop theme %s", link)
		}
		return nil
	}
	return os.Remove(link)
}
