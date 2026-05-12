"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  Archive,
  CalendarClock,
  CheckCircle2,
  Database,
  Download,
  Play,
  Radio,
  Search,
  ServerCog,
  ShieldCheck,
  Video,
} from "lucide-react";

import {
  createMeeting,
  exportMeetingMarkdown,
  getAssetAccess,
  getJobStatus,
  joinMeeting,
  listMeetings,
  mapApiMeeting,
  searchMeetings,
  simulateRecordingFinished,
  startRecording,
  type SearchResult,
} from "../lib/api-client";
import { getMockDashboard } from "../lib/mock-data";
import type { JobStatus, Meeting } from "../lib/types";
import { StatusPill } from "./status-pill";

type EventLog = {
  label: string;
  detail: string;
};

export function MvpConsole() {
  const mock = getMockDashboard();
  const [meetings, setMeetings] = useState<Meeting[]>(mock.meetings);
  const [searchQuery, setSearchQuery] = useState("budget");
  const [searchResults, setSearchResults] = useState<SearchResult[]>(mock.searchResults);
  const [selectedMeetingId, setSelectedMeetingId] = useState(mock.meetings[0]?.id ?? "");
  const [logs, setLogs] = useState<EventLog[]>([
    { label: "系统", detail: "Mock MVP 已启动，等待 API 同步。" },
  ]);
  const [isLoading, setIsLoading] = useState(false);
  const [newMeetingTitle, setNewMeetingTitle] = useState("试点客户部署评审");
  const [jobStatus, setJobStatus] = useState<{ id: string; status: JobStatus | "processing"; stage: string } | null>(
    mock.jobs[1] ? { id: mock.jobs[1].id, status: mock.jobs[1].status, stage: mock.jobs[1].stage } : null
  );

  useEffect(() => {
    void refreshMeetings();
  }, []);

  const selectedMeeting = useMemo(
    () => meetings.find((meeting) => meeting.id === selectedMeetingId) ?? meetings[0],
    [meetings, selectedMeetingId]
  );
  const liveMeeting = meetings.find((meeting) => meeting.status === "live") ?? selectedMeeting;

  async function refreshMeetings() {
    try {
      const apiMeetings = await listMeetings();
      const mapped = apiMeetings.map(mapApiMeeting);
      setMeetings(mapped);
      if (mapped[0] && !selectedMeetingId) {
        setSelectedMeetingId(mapped[0].id);
      }
      addLog("API", `已同步 ${mapped.length} 场会议。`);
    } catch (error) {
      addLog("API", `同步失败，继续使用本地 mock：${errorMessage(error)}`);
    }
  }

  async function handleCreateMeeting() {
    await runAction("创建会议", async () => {
      const created = await createMeeting({ title: newMeetingTitle, hostUserId: "u-001" });
      const mapped = mapApiMeeting(created);
      setMeetings((current) => [mapped, ...current]);
      setSelectedMeetingId(mapped.id);
      addLog("会议", `已创建 ${created.title}，房间 ${created.roomName}。`);
    });
  }

  async function handleSearch() {
    await runAction("搜索", async () => {
      const results = await searchMeetings(searchQuery);
      setSearchResults(results);
      addLog("搜索", `关键词 "${searchQuery}" 返回 ${results.length} 条命中。`);
    });
  }

  async function handleJoinMeeting() {
    if (!selectedMeeting) return;
    await runAction("进入会议", async () => {
      const response = await joinMeeting(selectedMeeting.id);
      addLog("LiveKit", `获取 token 成功：${response.roomName} / ${response.livekitUrl}`);
    });
  }

  async function handleStartRecording() {
    if (!selectedMeeting) return;
    await runAction("启动录制", async () => {
      const response = await startRecording(selectedMeeting.id);
      addLog("录制", `mock egress 已启动：${response.egressId}。`);
    });
  }

  async function handleFinishRecording() {
    if (!selectedMeeting) return;
    await runAction("模拟录制完成", async () => {
      const response = await simulateRecordingFinished(selectedMeeting.roomName);
      const job = await getJobStatus(response.jobId);
      setJobStatus({ id: job.jobId, status: job.status as JobStatus, stage: job.stage });
      addLog("会后处理", `录制完成事件已触发任务 ${job.jobId}，当前阶段：${job.stage}。`);
    });
  }

  async function handleAssetAccess() {
    if (!selectedMeeting) return;
    await runAction("资产访问", async () => {
      const response = await getAssetAccess(selectedMeeting.id);
      addLog("资产", `viewer 可访问 ${response.assetType}：${response.uri}`);
    });
  }

  async function handleExport() {
    if (!selectedMeeting) return;
    await runAction("导出纪要", async () => {
      const markdown = await exportMeetingMarkdown(selectedMeeting.id);
      addLog("导出", markdown.split("\n")[0] || "Markdown 已生成。");
    });
  }

  async function runAction(label: string, action: () => Promise<void>) {
    setIsLoading(true);
    try {
      await action();
    } catch (error) {
      addLog(label, errorMessage(error));
    } finally {
      setIsLoading(false);
    }
  }

  function addLog(label: string, detail: string) {
    setLogs((current) => [{ label, detail }, ...current].slice(0, 6));
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">私有化 AI 会议试点控制台</p>
          <h1>AI Meeting</h1>
        </div>
        <div className="top-actions">
          <button className="icon-button" aria-label="搜索会议" onClick={handleSearch} disabled={isLoading}>
            <Search size={18} />
          </button>
          <button className="primary-action" onClick={handleCreateMeeting} disabled={isLoading}>
            <Video size={18} />
            发起会议
          </button>
        </div>
      </header>

      <section className="overview">
        <div className="hero-panel">
          <div>
            <p className="eyebrow">当前会议</p>
            <h2>{liveMeeting?.title ?? "暂无会议"}</h2>
            <p>{liveMeeting?.summary ?? "Mock 数据已准备，可继续对接 LiveKit 房间和 API。"}</p>
            <div className="form-row">
              <input
                aria-label="新会议标题"
                value={newMeetingTitle}
                onChange={(event) => setNewMeetingTitle(event.target.value)}
              />
              <button className="secondary-action" onClick={handleCreateMeeting} disabled={isLoading}>
                创建
              </button>
            </div>
          </div>
          <div className="meeting-stage">
            <div className="video-frame">
              <div className="speaker">周敏</div>
              <div className="waveform">
                <span />
                <span />
                <span />
                <span />
                <span />
              </div>
            </div>
            <div className="stage-actions">
              <button className="primary-action" onClick={handleJoinMeeting} disabled={isLoading}>
                <Play size={16} />
                进入房间
              </button>
              <button className="secondary-action" onClick={handleStartRecording} disabled={isLoading}>
                <Radio size={16} />
                启动录制
              </button>
              <button className="secondary-action" onClick={handleFinishRecording} disabled={isLoading}>
                <Archive size={16} />
                完成录制
              </button>
            </div>
          </div>
        </div>
        <div className="metric-grid">
          <Metric icon={<CalendarClock size={19} />} label="会议" value={meetings.length.toString()} />
          <Metric icon={<Activity size={19} />} label="任务阶段" value={jobStatus?.stage ?? "mock"} />
          <Metric icon={<Database size={19} />} label="中间件" value={mock.middleware.length.toString()} />
          <Metric icon={<ShieldCheck size={19} />} label="资产边界" value="客户域" />
        </div>
      </section>

      <section className="content-grid">
        <div className="panel wide">
          <div className="panel-heading">
            <h2>会议与纪要</h2>
            <button className="secondary-action" onClick={refreshMeetings} disabled={isLoading}>
              同步 API
            </button>
          </div>
          <div className="table-list">
            {meetings.map((meeting) => (
              <button
                className={`meeting-row selectable ${meeting.id === selectedMeeting?.id ? "selected" : ""}`}
                key={meeting.id}
                onClick={() => setSelectedMeetingId(meeting.id)}
              >
                <div>
                  <div className="row-title">
                    <h3>{meeting.title}</h3>
                    <StatusPill status={meeting.status} />
                  </div>
                  <p>{meeting.summary}</p>
                  <small>
                    {meeting.startTime} · {meeting.participants} 人 · {meeting.roomName}
                  </small>
                </div>
                <code>{meeting.storageUri}</code>
              </button>
            ))}
          </div>
        </div>

        <div className="panel">
          <div className="panel-heading">
            <h2>会后流水线</h2>
            <ServerCog size={19} />
          </div>
          <div className="job-list">
            {mock.jobs.map((job) => (
              <article className="job-item" key={job.id}>
                <div className="row-title">
                  <h3>{job.title}</h3>
                  <StatusPill status={job.status} />
                </div>
                <p>{job.id === jobStatus?.id ? jobStatus.stage : job.stage}</p>
                <div className="progress-track" aria-label={`${job.progress}%`}>
                  <div style={{ width: `${job.progress}%` }} />
                </div>
                <small>{job.updatedAt}</small>
              </article>
            ))}
          </div>
          <div className="action-stack">
            <button className="secondary-action" onClick={handleAssetAccess} disabled={isLoading}>
              <ShieldCheck size={16} />
              校验资产权限
            </button>
            <button className="secondary-action" onClick={handleExport} disabled={isLoading}>
              <Download size={16} />
              导出纪要
            </button>
          </div>
        </div>
      </section>

      <section className="content-grid">
        <div className="panel">
          <div className="panel-heading">
            <h2>搜索结果</h2>
            <Search size={19} />
          </div>
          <div className="form-row">
            <input
              aria-label="搜索关键词"
              value={searchQuery}
              onChange={(event) => setSearchQuery(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") void handleSearch();
              }}
            />
            <button className="secondary-action" onClick={handleSearch} disabled={isLoading}>
              搜索
            </button>
          </div>
          {searchResults.map((result) => (
            <article className="search-hit" key={`${result.meetingId}-${result.timestamp}`}>
              <h3>{result.title}</h3>
              <p>{result.snippet}</p>
              <small>
                {result.speaker} · {result.timestamp}
              </small>
            </article>
          ))}
        </div>

        <div className="panel wide">
          <div className="panel-heading">
            <h2>中间件接入状态</h2>
            <CheckCircle2 size={19} />
          </div>
          <div className="middleware-grid">
            {mock.middleware.map((item) => (
              <article className="middleware-card" key={item.name}>
                <div className="row-title">
                  <h3>{item.name}</h3>
                  <StatusPill status={item.status} />
                </div>
                <p>{item.role}</p>
                <code>{item.endpoint}</code>
                <small>{item.configFile}</small>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="panel log-panel">
        <div className="panel-heading">
          <h2>操作日志</h2>
          <span className="muted">{isLoading ? "请求中" : "可操作"}</span>
        </div>
        {logs.map((item, index) => (
          <div className="log-row" key={`${item.label}-${index}`}>
            <strong>{item.label}</strong>
            <span>{item.detail}</span>
          </div>
        ))}
      </section>
    </main>
  );
}

function Metric({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="metric-card">
      <div className="metric-icon">{icon}</div>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "请求失败";
}
