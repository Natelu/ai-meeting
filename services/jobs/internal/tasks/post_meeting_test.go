package tasks_test

import (
	"testing"

	"github.com/ai-meeting/services/jobs/internal/tasks"
)

func TestPostMeetingTaskReturnsSummaryPayload(t *testing.T) {
	result := tasks.ProcessPostMeetingAsset("meeting-123", "/tmp/audio.wav")

	if result.MeetingID != "meeting-123" {
		t.Fatalf("unexpected meeting id: %s", result.MeetingID)
	}
	if result.Summary == "" {
		t.Fatal("expected summary")
	}
	if len(result.Todos) == 0 {
		t.Fatal("expected todos")
	}
	if result.StorageURI == "" {
		t.Fatal("expected storage uri")
	}
}
