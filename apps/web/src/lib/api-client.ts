import type { Meeting } from "./types";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8080";

export interface ApiMeeting {
  id: string;
  title: string;
  hostUserId: string;
  status: "scheduled" | "live" | "ended";
  roomName: string;
  startTime?: string;
  endTime?: string;
}

export interface CreateMeetingInput {
  title: string;
  hostUserId: string;
}

export interface SearchResult {
  meetingId: string;
  title: string;
  speaker: string;
  snippet: string;
  timestamp: string;
}

export interface JoinMeetingResponse {
  meetingId: string;
  roomName: string;
  token: string;
  livekitUrl: string;
}

export interface RecordingResponse {
  meetingId: string;
  roomName: string;
  egressId: string;
  status: string;
}

export interface WebhookResponse {
  jobId: string;
  roomName: string;
  status: string;
}

export interface JobStatusResponse {
  jobId: string;
  status: string;
  stage: string;
  message: string;
}

export interface AssetAccessResponse {
  meetingId: string;
  assetType: string;
  uri: string;
  allowed: boolean;
}

export async function listMeetings(): Promise<ApiMeeting[]> {
  const payload = await request<{ meetings: ApiMeeting[] }>("/api/meetings");
  return payload.meetings;
}

export async function createMeeting(input: CreateMeetingInput): Promise<ApiMeeting> {
  return request<ApiMeeting>("/api/meetings", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export async function searchMeetings(query: string): Promise<SearchResult[]> {
  const payload = await request<{ results: SearchResult[] }>(`/api/search?q=${encodeURIComponent(query)}`);
  return payload.results;
}

export async function joinMeeting(meetingId: string): Promise<JoinMeetingResponse> {
  return request<JoinMeetingResponse>(`/api/meetings/${meetingId}/join`, {
    method: "POST",
    body: JSON.stringify({ userId: "u-001", displayName: "陈越" }),
  });
}

export async function startRecording(meetingId: string): Promise<RecordingResponse> {
  return request<RecordingResponse>(`/api/meetings/${meetingId}/recording/start`, {
    method: "POST",
  });
}

export async function simulateRecordingFinished(roomName: string): Promise<WebhookResponse> {
  return request<WebhookResponse>("/webhooks/livekit", {
    method: "POST",
    body: JSON.stringify({ event: "egress_ended", roomName }),
  });
}

export async function getJobStatus(jobId: string): Promise<JobStatusResponse> {
  return request<JobStatusResponse>(`/api/jobs/${jobId}`);
}

export async function getAssetAccess(meetingId: string, assetType = "recording"): Promise<AssetAccessResponse> {
  return request<AssetAccessResponse>(`/api/meetings/${meetingId}/assets/${assetType}?role=viewer`);
}

export async function exportMeetingMarkdown(meetingId: string): Promise<string> {
  const response = await fetch(`${API_BASE_URL}/api/meetings/${meetingId}/export?format=markdown`);
  if (!response.ok) {
    throw new Error(`Export failed: ${response.status}`);
  }
  return response.text();
}

export function mapApiMeeting(meeting: ApiMeeting): Meeting {
  return {
    id: meeting.id,
    title: meeting.title,
    owner: meeting.hostUserId,
    status: meeting.status,
    startTime: meeting.startTime?.replace("T", " ").slice(0, 16) ?? "待定",
    duration: meeting.status === "live" ? "进行中" : meeting.status === "ended" ? "已结束" : "45 分钟",
    participants: meeting.status === "live" ? 9 : 12,
    summary: meeting.status === "ended" ? "会后纪要、待办和归档已生成。" : "等待会议流程推进。",
    storageUri: `s3://meeting-assets/mock/${meeting.id}`,
    roomName: meeting.roomName,
  };
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...init.headers,
    },
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `Request failed: ${response.status}`);
  }
  return response.json() as Promise<T>;
}
