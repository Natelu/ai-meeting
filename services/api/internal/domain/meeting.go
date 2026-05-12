package domain

type MeetingStatus string

const (
	MeetingStatusScheduled MeetingStatus = "scheduled"
	MeetingStatusLive      MeetingStatus = "live"
	MeetingStatusEnded     MeetingStatus = "ended"
)

type Meeting struct {
	ID         string        `json:"id"`
	Title      string        `json:"title"`
	HostUserID string        `json:"hostUserId"`
	Status     MeetingStatus `json:"status"`
	RoomName   string        `json:"roomName"`
	StartTime  string        `json:"startTime,omitempty"`
	EndTime    string        `json:"endTime,omitempty"`
}

type Todo struct {
	Owner   string `json:"owner"`
	Content string `json:"content"`
	Due     string `json:"due"`
}

type MeetingSummary struct {
	MeetingID  string `json:"meetingId"`
	Summary    string `json:"summary"`
	Todos      []Todo `json:"todos"`
	StorageURI string `json:"storageUri"`
}
