package http_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func TestAssetAccessAllowsViewerRole(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/meetings/m-001/assets/recording?role=viewer", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d with body %s", rec.Code, rec.Body.String())
	}

	var payload struct {
		MeetingID string `json:"meetingId"`
		AssetType string `json:"assetType"`
		URI       string `json:"uri"`
		Allowed   bool   `json:"allowed"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !payload.Allowed || payload.URI == "" || payload.AssetType != "recording" {
		t.Fatalf("unexpected asset payload: %+v", payload)
	}
}

func TestAssetAccessRejectsUnknownRole(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/meetings/m-001/assets/recording?role=guest", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d with body %s", rec.Code, rec.Body.String())
	}
}
