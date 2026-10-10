package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestProtectBrowserMutations(t *testing.T) {
	hits := 0
	handler := protectBrowserMutations(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		w.WriteHeader(http.StatusNoContent)
	}))

	tests := []struct {
		name   string
		method string
		origin string
		want   int
		hit    bool
	}{
		{name: "foreign website cannot post", method: http.MethodPost, origin: "https://evil.example", want: http.StatusForbidden},
		{name: "dashboard may post", method: http.MethodPost, origin: "http://127.0.0.1:3600", want: http.StatusNoContent, hit: true},
		{name: "localhost dashboard may patch", method: http.MethodPatch, origin: "http://localhost:3600", want: http.StatusNoContent, hit: true},
		{name: "CLI without origin may post", method: http.MethodPost, want: http.StatusNoContent, hit: true},
		{name: "foreign read remains a read", method: http.MethodGet, origin: "https://evil.example", want: http.StatusNoContent, hit: true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			before := hits
			req := httptest.NewRequest(tc.method, "/api/test", nil)
			if tc.origin != "" {
				req.Header.Set("Origin", tc.origin)
			}
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)
			if rec.Code != tc.want {
				t.Fatalf("status = %d, want %d", rec.Code, tc.want)
			}
			gotHit := hits == before+1
			if gotHit != tc.hit {
				t.Fatalf("downstream hit = %v, want %v", gotHit, tc.hit)
			}
		})
	}
}
