export type MeetingId = string;
export type MeetingStatus = "scheduled" | "live" | "ended";
export type JobStatus = "queued" | "processing" | "done" | "failed";

export interface MeetingSummary {
  meetingId: MeetingId;
  title: string;
  status: MeetingStatus;
  roomName: string;
  storageUri?: string;
}

export interface RecordingEvent {
  event: "egress_ended";
  roomName: string;
}

export interface PostMeetingJob {
  jobId: string;
  meetingId: MeetingId;
  status: JobStatus;
  stage: "recording" | "transcription" | "summary" | "storage" | "index";
}
