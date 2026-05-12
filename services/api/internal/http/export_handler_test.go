package http_test

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func TestExportMeetingSummaryAsMarkdown(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/meetings/m-001/export?format=markdown", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); got != "text/markdown; charset=utf-8" {
		t.Fatalf("expected markdown content type, got %q", got)
	}
	if body := rec.Body.String(); !strings.Contains(body, "#") {
		t.Fatalf("expected markdown body, got %q", body)
	}
}

func TestExportMeetingSummaryAsJSON(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/meetings/m-001/export?format=json", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); got != "application/json; charset=utf-8" {
		t.Fatalf("expected json content type, got %q", got)
	}
	if body := rec.Body.String(); !strings.Contains(body, `"meetingId":"m-001"`) {
		t.Fatalf("expected json body, got %q", body)
	}
}
