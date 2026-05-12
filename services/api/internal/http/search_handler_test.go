package http_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func TestSearchReturnsMatchingMeetingSnippets(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/search?q=budget", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var payload struct {
		Results []struct {
			MeetingID string `json:"meetingId"`
			Snippet   string `json:"snippet"`
		} `json:"results"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(payload.Results) == 0 {
		t.Fatal("expected mock search results")
	}
}
