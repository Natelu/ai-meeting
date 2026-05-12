package http_test

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func TestMetricsEndpointExists(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "app_up 1") {
		t.Fatalf("expected app_up metric, got %q", rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "meeting_mock_jobs_processing") {
		t.Fatalf("expected jobs metric, got %q", rec.Body.String())
	}
}
