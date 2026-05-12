package service

type SearchResult struct {
	MeetingID string `json:"meetingId"`
	Title     string `json:"title"`
	Speaker   string `json:"speaker"`
	Snippet   string `json:"snippet"`
	Timestamp string `json:"timestamp"`
}

type SearchService struct{}

func NewSearchService() SearchService {
	return SearchService{}
}

func (SearchService) Search(query string) []SearchResult {
	if query == "" {
		query = "meeting"
	}
	return []SearchResult{
		{
			MeetingID: "m-001",
			Title:     "经营预算复盘",
			Speaker:   "陈越",
			Snippet:   "预算审批和客户存储配置需要在试点启动前完成。",
			Timestamp: "00:12:38",
		},
		{
			MeetingID: "m-002",
			Title:     "产品迭代评审",
			Speaker:   "周敏",
			Snippet:   "LiveKit 录制完成后触发转写、纪要和归档任务。",
			Timestamp: "00:08:11",
		},
	}
}
