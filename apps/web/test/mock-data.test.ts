import { describe, expect, it } from "vitest";

import { getMockDashboard } from "../src/lib/mock-data";

describe("mock dashboard data", () => {
  it("provides meetings, pipeline jobs, and middleware health for the web dashboard", () => {
    const dashboard = getMockDashboard();

    expect(dashboard.meetings.length).toBeGreaterThanOrEqual(3);
    expect(dashboard.jobs.some((job) => job.status === "processing")).toBe(true);
    expect(dashboard.middleware.map((item) => item.name)).toEqual(
      expect.arrayContaining(["PostgreSQL", "Redis", "MinIO", "LiveKit", "ASR", "LLM"])
    );
  });
});
