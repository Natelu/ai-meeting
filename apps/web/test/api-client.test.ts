import { afterEach, describe, expect, it, vi } from "vitest";

import {
  createMeeting,
  joinMeeting,
  mapApiMeeting,
  searchMeetings,
  simulateRecordingFinished,
  startRecording,
} from "../src/lib/api-client";

describe("api client", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("maps API meetings into dashboard meetings", () => {
    const mapped = mapApiMeeting({
      id: "m-001",
      title: "Weekly Review",
      hostUserId: "u-001",
      status: "live",
      roomName: "meeting-m-001",
      startTime: "2026-04-30T10:00:00+08:00",
    });

    expect(mapped.title).toBe("Weekly Review");
    expect(mapped.status).toBe("live");
    expect(mapped.duration).toBe("进行中");
    expect(mapped.storageUri).toContain("m-001");
  });

  it("calls the MVP API endpoints used by the interactive console", async () => {
    const calls: Array<{ url: string; init?: RequestInit }> = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string, init?: RequestInit) => {
        calls.push({ url, init });
        if (url.endsWith("/api/meetings")) {
          return jsonResponse({ id: "m-new", title: "试点", hostUserId: "u-001", status: "scheduled", roomName: "meeting-m-new" });
        }
        if (url.includes("/api/search")) {
          return jsonResponse({ results: [{ meetingId: "m-001", title: "预算", speaker: "陈越", snippet: "预算", timestamp: "00:01" }] });
        }
        if (url.endsWith("/join")) {
          return jsonResponse({ meetingId: "m-001", roomName: "meeting-m-001", token: "mock-token", livekitUrl: "ws://localhost:7880" });
        }
        if (url.endsWith("/recording/start")) {
          return jsonResponse({ meetingId: "m-001", roomName: "meeting-m-001", egressId: "egress-001", status: "recording" });
        }
        if (url.endsWith("/webhooks/livekit")) {
          return jsonResponse({ jobId: "job-001", roomName: "meeting-m-001", status: "accepted" });
        }
        throw new Error(`unexpected URL ${url}`);
      })
    );

    await createMeeting({ title: "试点", hostUserId: "u-001" });
    await searchMeetings("budget");
    await joinMeeting("m-001");
    await startRecording("m-001");
    await simulateRecordingFinished("meeting-m-001");

    expect(calls.map((call) => call.url)).toEqual([
      "http://localhost:8080/api/meetings",
      "http://localhost:8080/api/search?q=budget",
      "http://localhost:8080/api/meetings/m-001/join",
      "http://localhost:8080/api/meetings/m-001/recording/start",
      "http://localhost:8080/webhooks/livekit",
    ]);
    expect(calls[0].init?.method).toBe("POST");
    expect(calls[4].init?.body).toBe(JSON.stringify({ event: "egress_ended", roomName: "meeting-m-001" }));
  });
});

function jsonResponse(body: unknown): Response {
  return {
    ok: true,
    json: async () => body,
    text: async () => JSON.stringify(body),
  } as Response;
}
