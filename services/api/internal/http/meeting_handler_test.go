package http_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func TestCreateMeetingReturnsScheduledStatus(t *testing.T) {
	body := strings.NewReader(`{"title":"Weekly Review","hostUserId":"u-001"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/meetings", body)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d with body %s", rec.Code, rec.Body.String())
	}

	var payload struct {
		ID         string `json:"id"`
		Title      string `json:"title"`
		HostUserID string `json:"hostUserId"`
		Status     string `json:"status"`
		RoomName   string `json:"roomName"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.ID == "" || payload.RoomName == "" {
		t.Fatalf("expected ids to be populated: %+v", payload)
	}
	if payload.Title != "Weekly Review" || payload.HostUserID != "u-001" || payload.Status != "scheduled" {
		t.Fatalf("unexpected meeting payload: %+v", payload)
	}
}

func TestListMeetingsReturnsMockMeetings(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/meetings", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var payload struct {
		Meetings []struct {
			ID     string `json:"id"`
			Status string `json:"status"`
		} `json:"meetings"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(payload.Meetings) < 2 {
		t.Fatalf("expected at least two mock meetings, got %d", len(payload.Meetings))
	}
}

func TestGetMeetingSummaryReturnsTodosAndStorageURI(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/meetings/m-001/summary", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var payload struct {
		MeetingID  string `json:"meetingId"`
		Summary    string `json:"summary"`
		Todos      []any  `json:"todos"`
		StorageURI string `json:"storageUri"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.MeetingID != "m-001" || payload.Summary == "" || len(payload.Todos) == 0 || payload.StorageURI == "" {
		t.Fatalf("unexpected summary payload: %+v", payload)
	}
}
