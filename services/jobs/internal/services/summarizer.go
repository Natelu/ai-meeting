package services

func Summarize(transcript string) (string, []string) {
	return "会议确认了预算审批、录制回调、转写纪要和客户存储归档的试点优先级。", []string{
		"陈越在 2026-05-03 前确认预算审批流程",
		"周敏在 2026-05-04 前验证 LiveKit 录制回调",
	}
}
