package doctor

import (
	"path/filepath"
	"testing"
)

// isolateProvisioned points the provisioned ledger at a throwaway per-test file
// so a test that records a provision cannot pollute the real state dir and flip
// removedByUser for a later test. Without it, an install test's write made a
// check-only test on a host lacking that package (every CI runner) read it as
// "removed by hand" and fail.
func isolateProvisioned(t *testing.T) {
	t.Helper()
	old := provisionedFile
	path := filepath.Join(t.TempDir(), "provisioned")
	provisionedFile = func() string { return path }
	t.Cleanup(func() { provisionedFile = old })
}
