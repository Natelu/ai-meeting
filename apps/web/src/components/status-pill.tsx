import type { JobStatus, MeetingStatus, MiddlewareStatus } from "../lib/types";

type Status = MeetingStatus | JobStatus | MiddlewareStatus;

const labels: Record<Status, string> = {
  scheduled: "待开始",
  live: "会议中",
  ended: "已结束",
  queued: "排队中",
  processing: "处理中",
  done: "已完成",
  failed: "失败",
  ready: "已就绪",
  mocked: "Mock",
  needs_config: "待配置",
};

export function StatusPill({ status }: { status: Status }) {
  return <span className={`status status-${status}`}>{labels[status]}</span>;
}
