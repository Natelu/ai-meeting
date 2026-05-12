export type MeetingStatus = "scheduled" | "live" | "ended";
export type JobStatus = "queued" | "processing" | "done" | "failed";
export type MiddlewareStatus = "ready" | "mocked" | "needs_config";

export interface Meeting {
  id: string;
  title: string;
  owner: string;
  status: MeetingStatus;
  startTime: string;
  duration: string;
  participants: number;
  summary: string;
  storageUri: string;
  roomName: string;
}

export interface PipelineJob {
  id: string;
  meetingId: string;
  title: string;
  status: JobStatus;
  stage: string;
  progress: number;
  updatedAt: string;
}

export interface MiddlewareHealth {
  name: string;
  role: string;
  status: MiddlewareStatus;
  endpoint: string;
  configFile: string;
}

export interface DashboardData {
  meetings: Meeting[];
  jobs: PipelineJob[];
  middleware: MiddlewareHealth[];
  searchResults: Array<{
    meetingId: string;
    title: string;
    speaker: string;
    snippet: string;
    timestamp: string;
  }>;
}
