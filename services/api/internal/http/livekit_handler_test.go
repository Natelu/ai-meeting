package http_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func TestJoinMeetingReturnsMockLiveKitToken(t *testing.T) {
	body := strings.NewReader(`{"userId":"u-001","displayName":"陈越"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/meetings/m-001/join", body)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d with body %s", rec.Code, rec.Body.String())
	}

	var payload struct {
		MeetingID string `json:"meetingId"`
		RoomName  string `json:"roomName"`
		Token     string `json:"token"`
		LiveKitURL string `json:"livekitUrl"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.Token == "" || payload.LiveKitURL == "" || payload.RoomName == "" {
		t.Fatalf("expected mock livekit join payload, got %+v", payload)
	}
}

func TestStartRecordingReturnsMockEgress(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/api/meetings/m-001/recording/start", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d with body %s", rec.Code, rec.Body.String())
	}

	var payload struct {
		MeetingID string `json:"meetingId"`
		EgressID  string `json:"egressId"`
		Status    string `json:"status"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.EgressID == "" || payload.Status != "recording" {
		t.Fatalf("unexpected recording payload: %+v", payload)
	}
}
