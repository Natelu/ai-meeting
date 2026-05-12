package service

import (
	"encoding/json"
	"fmt"
	"strings"
)

type ExportService struct {
	meetings MeetingService
}

func NewExportService(meetings MeetingService) ExportService {
	return ExportService{meetings: meetings}
}

func (s ExportService) Markdown(meetingID string) string {
	summary := s.meetings.GetSummary(meetingID)
	var builder strings.Builder
	builder.WriteString(fmt.Sprintf("# 会议纪要 %s\n\n", meetingID))
	builder.WriteString("## 摘要\n\n")
	builder.WriteString(summary.Summary)
	builder.WriteString("\n\n## 待办\n\n")
	for _, todo := range summary.Todos {
		builder.WriteString(fmt.Sprintf("- [%s] %s（%s）\n", todo.Owner, todo.Content, todo.Due))
	}
	builder.WriteString("\n## 归档\n\n")
	builder.WriteString(summary.StorageURI)
	builder.WriteString("\n")
	return builder.String()
}

func (s ExportService) JSON(meetingID string) ([]byte, error) {
	return json.Marshal(s.meetings.GetSummary(meetingID))
}
