package main

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestPickerGraphicsEnv(t *testing.T) {
	const cacheRHI = "QSG_RHI_DISABLE_DISK_CACHE=1"
	const cacheShader = "QT_DISABLE_SHADER_DISK_CACHE=1"

	tests := []struct {
		name             string
		nvidiaDriver     bool
		nvidiaICD        bool
		inheritedBackend string
		want             []string
	}{
		{
			name:         "NVIDIA with Vulkan ICD",
			nvidiaDriver: true,
			nvidiaICD:    true,
			want:         []string{cacheRHI, cacheShader, "QSG_RHI_BACKEND=vulkan"},
		},
		{
			name:         "NVIDIA without Vulkan ICD",
			nvidiaDriver: true,
			want:         []string{cacheRHI, cacheShader},
		},
		{
			name:      "Vulkan ICD without NVIDIA driver",
			nvidiaICD: true,
			want:      []string{cacheRHI, cacheShader},
		},
		{
			name:             "inherited backend override",
			nvidiaDriver:     true,
			nvidiaICD:        true,
			inheritedBackend: "opengl",
			want:             []string{cacheRHI, cacheShader},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			root := t.TempDir()
			driver := filepath.Join(root, "proc", "driver", "nvidia", "version")
			icd := filepath.Join(root, "vulkan", "icd.d", "nvidia_icd.json")
			if tt.nvidiaDriver {
				if err := os.MkdirAll(filepath.Dir(driver), 0o755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(driver, []byte("NVIDIA"), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			if tt.nvidiaICD {
				if err := os.MkdirAll(filepath.Dir(icd), 0o755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(icd, []byte("{}"), 0o644); err != nil {
					t.Fatal(err)
				}
			}

			got := pickerGraphicsEnv(driver, []string{icd}, tt.inheritedBackend)
			if !slices.Equal(got, tt.want) {
				t.Fatalf("pickerGraphicsEnv() = %q, want %q", got, tt.want)
			}
		})
	}
}
