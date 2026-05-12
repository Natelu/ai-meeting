package livekit

type RecordingEvent struct {
	Event    string `json:"event"`
	RoomName string `json:"roomName"`
}

type RecordingJob struct {
	JobID    string `json:"jobId"`
	RoomName string `json:"roomName"`
	Status   string `json:"status"`
}

type JoinResponse struct {
	MeetingID  string `json:"meetingId"`
	RoomName   string `json:"roomName"`
	Token      string `json:"token"`
	LiveKitURL string `json:"livekitUrl"`
}

type RecordingResponse struct {
	MeetingID string `json:"meetingId"`
	RoomName  string `json:"roomName"`
	EgressID  string `json:"egressId"`
	Status    string `json:"status"`
}
