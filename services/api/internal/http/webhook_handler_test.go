package http_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func TestRecordingFinishedWebhookCreatesProcessingJob(t *testing.T) {
	body := strings.NewReader(`{"event":"egress_ended","roomName":"meeting-123"}`)
	req := httptest.NewRequest(http.MethodPost, "/webhooks/livekit", body)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d with body %s", rec.Code, rec.Body.String())
	}

	var payload struct {
		Status   string `json:"status"`
		RoomName string `json:"roomName"`
		JobID    string `json:"jobId"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.Status != "accepted" || payload.RoomName != "meeting-123" || payload.JobID == "" {
		t.Fatalf("unexpected webhook response: %+v", payload)
	}
}
