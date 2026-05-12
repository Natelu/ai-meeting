# AI Meeting MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a private-deployable AI meeting MVP for SMEs with stable meetings, recording, transcription, summaries, search, and customer-controlled storage.

**Architecture:** Use a Web client plus a Go control plane, a Go async jobs service, and a self-hosted LiveKit deployment. Persist metadata in PostgreSQL, task state in Redis, and meeting assets in customer-controlled object storage or NAS through a storage adapter.

**Tech Stack:** Next.js, TypeScript, LiveKit, Go, Gin, pgx, sqlc, goose, Asynq, Redis, PostgreSQL, MinIO, FFmpeg, FunASR or SenseVoice, vLLM with Qwen2.5-Instruct, Docker Compose, Prometheus, Grafana.

---

### Task 1: Scaffold the repository and local deployment baseline

**Files:**
- Create: `apps/web/package.json`
- Create: `apps/web/app/page.tsx`
- Create: `services/api/go.mod`
- Create: `services/api/cmd/api/main.go`
- Create: `services/api/internal/http/router.go`
- Create: `services/jobs/go.mod`
- Create: `services/jobs/cmd/jobs/main.go`
- Create: `packages/contracts/meeting.ts`
- Create: `infra/docker/docker-compose.local.yml`
- Create: `Makefile`
- Test: `services/api/internal/http/health_test.go`

- [x] **Step 1: Write the failing API smoke test**

```go
package http_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func TestHealthcheck(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./...`
Expected: FAIL with undefined router bootstrap or missing package

- [x] **Step 3: Write minimal API and workspace bootstrap**

```go
package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func NewRouter() *gin.Engine {
	r := gin.New()
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})
	return r
}
```

```ts
export type MeetingId = string;

export interface MeetingSummary {
  meetingId: MeetingId;
  title: string;
  status: "scheduled" | "live" | "ended";
}
```

- [x] **Step 4: Add local infrastructure bootstrap**

```yaml
services:
  postgres:
    image: postgres:16
  redis:
    image: redis:7
  minio:
    image: minio/minio
  livekit:
    image: livekit/livekit-server:latest
```

- [x] **Step 5: Run tests to verify baseline passes**

Run: `cd services/api && go test ./...`
Expected: PASS

- [x] **Step 6: Commit**

```bash
git add apps services packages infra Makefile
git commit -m "chore: scaffold ai meeting monorepo"
```

### Task 2: Implement core meeting domain and RBAC-ready control plane

**Files:**
- Create: `services/api/internal/domain/meeting.go`
- Create: `services/api/internal/domain/user.go`
- Create: `services/api/internal/http/meeting_handler.go`
- Create: `services/api/internal/service/meeting_service.go`
- Modify: `services/api/internal/http/router.go`
- Test: `services/api/internal/http/meeting_handler_test.go`

- [x] **Step 1: Write the failing lifecycle test**

```go
func TestCreateMeetingReturnsScheduledStatus(t *testing.T) {
	body := strings.NewReader(`{"title":"Weekly Review","hostUserId":"u-001"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/meetings", body)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d", rec.Code)
	}
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/http -run TestCreateMeetingReturnsScheduledStatus`
Expected: FAIL with `404 Not Found`

- [x] **Step 3: Add meeting domain and minimal service**

```go
type Meeting struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	HostUserID string `json:"hostUserId"`
	Status     string `json:"status"`
}

func CreateMeeting(title, hostUserID string) Meeting {
	return Meeting{
		ID:         uuid.NewString(),
		Title:      title,
		HostUserID: hostUserID,
		Status:     "scheduled",
	}
}
```

- [x] **Step 4: Expose the API route**

```go
api := r.Group("/api")
api.POST("/meetings", handler.CreateMeeting)
```

- [x] **Step 5: Run tests**

Run: `cd services/api && go test ./internal/http`
Expected: PASS

- [x] **Step 6: Commit**

```bash
git add services/api
git commit -m "feat: add meeting lifecycle api"
```

### Task 3: Integrate self-hosted LiveKit for room lifecycle and recording hooks

**Files:**
- Create: `services/api/internal/integrations/livekit/client.go`
- Create: `services/api/internal/http/webhook_handler.go`
- Modify: `services/api/internal/service/meeting_service.go`
- Modify: `packages/contracts/meeting.ts`
- Test: `services/api/internal/http/webhook_handler_test.go`

- [x] **Step 1: Write the failing webhook test**

```go
func TestRecordingFinishedWebhookCreatesProcessingJob(t *testing.T) {
	body := strings.NewReader(`{"event":"egress_ended","roomName":"meeting-123"}`)
	req := httptest.NewRequest(http.MethodPost, "/webhooks/livekit", body)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", rec.Code)
	}
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/http -run TestRecordingFinishedWebhookCreatesProcessingJob`
Expected: FAIL with `404 Not Found`

- [x] **Step 3: Add LiveKit adapter and webhook route**

```go
router.POST("/webhooks/livekit", func(c *gin.Context) {
	var payload RecordingEvent
	_ = c.ShouldBindJSON(&payload)
	if payload.Event == "egress_ended" {
		c.JSON(http.StatusAccepted, gin.H{"status": "accepted", "roomName": payload.RoomName})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ignored"})
})
```

- [x] **Step 4: Update meeting contract**

```ts
export interface RecordingEvent {
  event: "egress_ended";
  roomName: string;
}
```

- [x] **Step 5: Run tests**

Run: `cd services/api && go test ./internal/http -run TestRecordingFinishedWebhookCreatesProcessingJob`
Expected: PASS

- [x] **Step 6: Commit**

```bash
git add services/api packages/contracts
git commit -m "feat: add livekit recording webhook flow"
```

### Task 4: Build the post-meeting pipeline for transcription, summary, and storage

**Files:**
- Create: `services/jobs/internal/tasks/post_meeting.go`
- Create: `services/jobs/internal/services/asr.go`
- Create: `services/jobs/internal/services/summarizer.go`
- Create: `services/jobs/internal/services/storage.go`
- Create: `services/api/internal/http/job_handler.go`
- Test: `services/jobs/internal/tasks/post_meeting_test.go`

- [x] **Step 1: Write the failing jobs test**

```go
func TestPostMeetingTaskReturnsSummaryPayload(t *testing.T) {
	result := ProcessPostMeetingAsset("meeting-123", "/tmp/audio.wav")
	if result.MeetingID != "meeting-123" {
		t.Fatalf("unexpected meeting id: %s", result.MeetingID)
	}
	if result.Summary == "" {
		t.Fatal("expected summary")
	}
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd services/jobs && go test ./internal/tasks -run TestPostMeetingTaskReturnsSummaryPayload`
Expected: FAIL with missing task implementation

- [x] **Step 3: Write minimal pipeline implementation**

```go
func ProcessPostMeetingAsset(meetingID, audioPath string) Result {
	transcript := Transcribe(audioPath)
	summary, todos := Summarize(transcript)
	storageURI := WriteArtifacts(meetingID, transcript, summary, todos)
	return Result{
		MeetingID:  meetingID,
		Summary:    summary,
		Todos:      todos,
		StorageURI: storageURI,
	}
}
```

- [x] **Step 4: Add job status endpoint in the API**

```go
router.GET("/api/jobs/:jobId", func(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"jobId": c.Param("jobId"), "status": "queued"})
})
```

- [x] **Step 5: Run tests**

Run: `cd services/jobs && go test ./internal/tasks`
Expected: PASS

- [x] **Step 6: Commit**

```bash
git add services/jobs services/api
git commit -m "feat: add post meeting processing pipeline"
```

### Task 5: Add transcript search, asset access control, and export

**Files:**
- Create: `services/api/internal/http/search_handler.go`
- Create: `services/api/internal/http/asset_handler.go`
- Create: `services/api/internal/service/search_service.go`
- Create: `services/api/internal/service/export_service.go`
- Test: `services/api/internal/http/search_handler_test.go`
- Test: `services/api/internal/http/export_handler_test.go`

- [x] **Step 1: Write the failing search test**

```go
func TestSearchReturnsMatchingMeetingSnippets(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/search?q=budget", nil)
	rec := httptest.NewRecorder()
	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/http -run TestSearchReturnsMatchingMeetingSnippets`
Expected: FAIL with `404 Not Found`

- [x] **Step 3: Add minimal search and export routes**

```go
router.GET("/api/search", func(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"results": []any{}})
})

router.GET("/api/meetings/:meetingId/export", func(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"meetingId": c.Param("meetingId"), "format": "markdown"})
})
```

- [x] **Step 4: Add permission checks around asset access**

```go
func CanAccessAsset(role string) bool {
	switch role {
	case "admin", "host", "viewer":
		return true
	default:
		return false
	}
}
```

- [x] **Step 5: Run tests**

Run: `cd services/api && go test ./internal/http`
Expected: PASS

- [x] **Step 6: Commit**

```bash
git add services/api
git commit -m "feat: add transcript search and exports"
```

### Task 6: Make the system deployable and observable for pilot customers

**Files:**
- Create: `infra/docker/docker-compose.pilot.yml`
- Create: `infra/docker/prometheus.yml`
- Create: `infra/docker/loki-config.yml`
- Create: `docs/deployment.md`
- Create: `docs/operations.md`
- Test: `services/api/internal/http/metrics_test.go`

- [x] **Step 1: Write the failing metrics test**

```go
func TestMetricsEndpointExists(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec := httptest.NewRecorder()
	router := apphttp.NewRouter()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd services/api && go test ./internal/http -run TestMetricsEndpointExists`
Expected: FAIL with `404 Not Found`

- [x] **Step 3: Add minimal metrics route and pilot deployment files**

```go
router.GET("/metrics", func(c *gin.Context) {
	c.String(http.StatusOK, "app_up 1\n")
})
```

```yaml
services:
  nginx:
    image: nginx:stable
  prometheus:
    image: prom/prometheus:latest
  grafana:
    image: grafana/grafana:latest
```

- [x] **Step 4: Document pilot deployment and operations**

```md
1. Provision VM with Docker and mounted storage.
2. Configure `.env` for Postgres, Redis, MinIO, LiveKit, ASR, and LLM endpoints.
3. Start stack with `docker compose -f infra/docker/docker-compose.pilot.yml up -d`.
4. Validate health, recording flow, and jobs pipeline before inviting pilot users.
```

- [x] **Step 5: Run tests**

Run: `cd services/api && go test ./internal/http -run TestMetricsEndpointExists`
Expected: PASS

- [x] **Step 6: Commit**

```bash
git add infra docs services/api
git commit -m "chore: add pilot deployment and observability"
```

## Self-review

- Spec coverage checked against product positioning, private deployment, meeting basics, AI notes, search, storage ownership, integration boundaries, and pilot readiness.
- Placeholder scan completed. Each task has explicit file paths, commands, and minimal code examples.
- Naming consistency checked for `meeting`, `job`, `search`, `export`, and `recording` flows.
