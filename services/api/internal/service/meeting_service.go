package service

import (
	"fmt"
	"time"

	"github.com/ai-meeting/services/api/internal/domain"
	"github.com/google/uuid"
)

type MeetingService struct{}

func NewMeetingService() MeetingService {
	return MeetingService{}
}

func (MeetingService) CreateMeeting(title, hostUserID string) domain.Meeting {
	id := uuid.NewString()
	return domain.Meeting{
		ID:         id,
		Title:      title,
		HostUserID: hostUserID,
		Status:     domain.MeetingStatusScheduled,
		RoomName:   fmt.Sprintf("meeting-%s", id[:8]),
	}
}

func (MeetingService) ListMeetings() []domain.Meeting {
	return []domain.Meeting{
		{
			ID:         "m-001",
			Title:      "经营预算复盘",
			HostUserID: "u-001",
			Status:     domain.MeetingStatusEnded,
			RoomName:   "meeting-m-001",
			StartTime:  time.Now().Add(-2 * time.Hour).Format(time.RFC3339),
			EndTime:    time.Now().Add(-1 * time.Hour).Format(time.RFC3339),
		},
		{
			ID:         "m-002",
			Title:      "产品迭代评审",
			HostUserID: "u-002",
			Status:     domain.MeetingStatusLive,
			RoomName:   "meeting-m-002",
			StartTime:  time.Now().Add(-30 * time.Minute).Format(time.RFC3339),
		},
		{
			ID:         "m-003",
			Title:      "客户交付同步",
			HostUserID: "u-003",
			Status:     domain.MeetingStatusScheduled,
			RoomName:   "meeting-m-003",
			StartTime:  time.Now().Add(3 * time.Hour).Format(time.RFC3339),
		},
	}
}

func (MeetingService) GetSummary(meetingID string) domain.MeetingSummary {
	return domain.MeetingSummary{
		MeetingID: meetingID,
		Summary:   "本次会议确认了预算归档、客户存储接入和会后处理的优先级。",
		Todos: []domain.Todo{
			{Owner: "林辰", Content: "补齐 MinIO 存储桶初始化脚本", Due: "2026-05-03"},
			{Owner: "周敏", Content: "验证 LiveKit 录制回调链路", Due: "2026-05-04"},
		},
		StorageURI: "s3://meeting-assets/mock/" + meetingID + "/summary.md",
	}
}
