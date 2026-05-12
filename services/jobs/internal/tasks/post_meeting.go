package tasks

import "github.com/ai-meeting/services/jobs/internal/services"

type Result struct {
	MeetingID  string   `json:"meetingId"`
	Transcript string   `json:"transcript"`
	Summary    string   `json:"summary"`
	Todos      []string `json:"todos"`
	StorageURI string   `json:"storageUri"`
}

func ProcessPostMeetingAsset(meetingID, audioPath string) Result {
	transcript := services.Transcribe(audioPath)
	summary, todos := services.Summarize(transcript)
	storageURI := services.WriteArtifacts(meetingID, transcript, summary, todos)

	return Result{
		MeetingID:  meetingID,
		Transcript: transcript,
		Summary:    summary,
		Todos:      todos,
		StorageURI: storageURI,
	}
}
