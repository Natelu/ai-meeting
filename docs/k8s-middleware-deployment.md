# Kubernetes Middleware Deployment

This document describes the Kubernetes deployment architecture, component dependencies, and usage for the AI Meeting middleware Helm chart.

Chart path:

```text
infra/helm/ai-meeting-middleware
```

## 1. Deployment Architecture

The chart deploys middleware only. The AI Meeting application services can run in the same cluster later and consume these services through Kubernetes DNS, or run outside the cluster and connect through NodePort.

```text
                         ┌──────────────────────────────┐
                         │ Kubernetes NodePort Boundary  │
                         └──────────────┬───────────────┘
                                        │
         ┌──────────────────────────────┼──────────────────────────────┐
         │                              │                              │
  ┌──────▼──────┐              ┌────────▼────────┐             ┌───────▼───────┐
  │  LiveKit    │              │  Whisper ASR    │             │ Observability │
  │  Deployment │              │  Deployment     │             │ Prom/Graf/Loki│
  └──────┬──────┘              └────────┬────────┘             └───────┬───────┘
         │                              │                              │
         │                              │ initContainer                 │
         │                              ▼                              │
         │                     ┌──────────────────┐                    │
         │                     │ Existing MinIO S3│                    │
         │                     │ model bucket     │                    │
         │                     └──────────────────┘                    │
         │                                                             │
  ┌──────▼─────────────────────────────────────────────────────────────▼──────┐
  │                         Cluster Internal Network                           │
  └──────┬─────────────────────────────────────────────────────────────┬──────┘
         │                                                             │
 ┌───────▼────────┐                                          ┌─────────▼───────┐
 │ PostgreSQL HA  │                                          │ Redis HA        │
 │ CloudNativePG  │                                          │ Master/Replica  │
 │                │                                          │ Sentinel        │
 └────────────────┘                                          └─────────────────┘
```

### PostgreSQL

PostgreSQL is managed by CloudNativePG instead of a hand-written StatefulSet. The chart creates a `postgresql.cnpg.io/v1` `Cluster` with multiple instances.

CloudNativePG provides:

- primary/replica orchestration
- automatic failover
- managed services for read-write and read-only traffic
- PVC-based local disk persistence through the configured StorageClass

The chart additionally exposes read-write and read-only PostgreSQL services through NodePort for external application access.

### Redis

Redis is deployed as a password-protected master/replica topology with Sentinel. The master and replicas use AOF persistence and local hostPath disk under:

```text
{{ .Values.global.storageRoot }}/redis-master
{{ .Values.global.storageRoot }}/redis-replica
```

Sentinel is exposed separately through NodePort so clients that support Sentinel can discover the active master after failover.

### Whisper ASR

Whisper ASR runs as a GPU workload. Before the ASR container starts, an init container uses `minio/mc` to copy the model directory from the existing MinIO S3 bucket into an `emptyDir` volume.

The expected S3 layout is:

```text
s3://meeting-assets/models/whisper/large-v3/model.bin
s3://meeting-assets/models/whisper/large-v3/config.json
s3://meeting-assets/models/whisper/large-v3/...
```

The ASR container then reads the local mounted path:

```text
/models/large-v3
```

### LiveKit

LiveKit is deployed as a single Deployment and exposed with three NodePorts:

- WebSocket/API TCP
- RTC TCP
- RTC UDP

The chart configures `use_external_ip: true`, which is appropriate for NodePort exposure.

### Observability

Prometheus, Grafana, and Loki are deployed as lightweight single-instance services. Grafana and Loki use hostPath persistence and init containers to fix filesystem ownership.

## 2. Component Dependencies

Deployment dependency graph:

```text
CloudNativePG Operator
        │
        ▼
PostgreSQL Cluster ───────────────┐
                                  │
Redis Master/Replica/Sentinel ────┤
                                  │
LiveKit Config Secret/ConfigMap ──┤
                                  │
Existing MinIO S3 ──► ASR init ──► Whisper ASR
                                  │
Observability ConfigMaps ────────► Prometheus / Grafana / Loki
```

Runtime dependencies:

| Component | Depends on | Reason |
|---|---|---|
| PostgreSQL Cluster | CloudNativePG Operator, StorageClass | CRD reconciliation and persistent volumes |
| Redis | Local node disk path | AOF persistence, replication, Sentinel failover |
| LiveKit | LiveKit Secret and ConfigMap | API key/secret and server config |
| Whisper ASR | Existing MinIO S3, model files, GPU device plugin | Model sync and CUDA execution |
| Prometheus | ConfigMap | Scrape config |
| Grafana | Secret, local disk | Admin credentials and dashboard persistence |
| Loki | ConfigMap, local disk | Storage config and log chunks |

Operational startup order:

1. Install CloudNativePG operator.
2. Ensure local-path StorageClass or equivalent exists.
3. Upload Whisper model files to the existing MinIO bucket.
4. Install this Helm chart.
5. Wait for PostgreSQL cluster readiness.
6. Wait for ASR init container to copy models from MinIO.
7. Configure AI Meeting application env vars from the Helm output.

## 3. Usage

### Install CloudNativePG

```bash
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.2.yaml
kubectl get pods -n cnpg-system
```

### Prepare Whisper Model in Existing MinIO

Upload model files to the previously deployed MinIO bucket. Example using `mc`:

```bash
mc alias set meeting http://112.91.142.91:9000 <access-key> <secret-key>
mc mb -p meeting/meeting-assets
mc cp --recursive /mnt/data/ai-meeting/whisper/modelscope/large-v3/ meeting/meeting-assets/models/whisper/large-v3/
```

The chart's ASR init container will copy from:

```text
meeting-assets/models/whisper/large-v3/
```

### Create Override Values

Create `values-prod.yaml`:

```yaml
global:
  storageRoot: /mnt/data/k8s/ai-meeting

nodePorts:
  postgresRw: 30432
  postgresRo: 30433
  redis: 30379
  redisSentinel: 30380
  livekitWs: 30880
  livekitRtcTcp: 30881
  livekitRtcUdp: 30882
  whisperAsr: 30901
  prometheus: 30090
  grafana: 30031
  loki: 30100

secrets:
  postgres:
    username: ai_meeting
    password: replace-with-strong-password
    database: ai_meeting
  redis:
    password: replace-with-strong-password
  livekit:
    apiKey: replace-with-livekit-key
    apiSecret: replace-with-livekit-secret
  grafana:
    adminUser: admin
    adminPassword: replace-with-strong-password
  modelS3:
    accessKey: replace-with-minio-access-key
    secretKey: replace-with-minio-secret-key

postgres:
  instances: 3
  storage:
    storageClass: local-path
    size: 50Gi

modelS3:
  endpoint: http://112.91.142.91:9000
  bucket: meeting-assets
  prefix: models/whisper/large-v3

whisperAsr:
  model: large-v3
  gpuCount: 1
```

### Install Chart

```bash
helm upgrade --install middleware ./infra/helm/ai-meeting-middleware \
  -n ai-meeting --create-namespace \
  -f values-prod.yaml
```

### Verify Deployment

```bash
kubectl get pods -n ai-meeting
kubectl get cluster -n ai-meeting
kubectl get svc -n ai-meeting
```

Check PostgreSQL:

```bash
kubectl get cluster -n ai-meeting
kubectl describe cluster -n ai-meeting middleware-ai-meeting-middleware-postgres
```

Check ASR model sync:

```bash
kubectl logs -n ai-meeting deploy/middleware-ai-meeting-middleware-whisper-asr -c sync-model-from-minio
kubectl get pod -n ai-meeting -l app.kubernetes.io/component=whisper-asr
```

Check NodePort access:

```bash
curl http://<node-ip>:30901/docs
curl http://<node-ip>:30090/-/ready
curl http://<node-ip>:30031/api/health
curl http://<node-ip>:30100/ready
```

### Application Configuration

When the AI Meeting application runs inside the same namespace:

```env
POSTGRES_DSN=postgres://ai_meeting:<password>@middleware-ai-meeting-middleware-postgres-rw:5432/ai_meeting?sslmode=disable
REDIS_ADDR=middleware-ai-meeting-middleware-redis-master:6379
REDIS_SENTINEL_ADDR=middleware-ai-meeting-middleware-redis-sentinel:26379
LIVEKIT_URL=ws://middleware-ai-meeting-middleware-livekit:7880
ASR_BASE_URL=http://middleware-ai-meeting-middleware-whisper-asr:9000
```

When the application runs outside Kubernetes, use node IP plus NodePort:

```env
POSTGRES_DSN=postgres://ai_meeting:<password>@<node-ip>:30432/ai_meeting?sslmode=disable
REDIS_ADDR=<node-ip>:30379
REDIS_SENTINEL_ADDR=<node-ip>:30380
LIVEKIT_URL=ws://<node-ip>:30880
ASR_BASE_URL=http://<node-ip>:30901
```

### Notes

- Local disk persistence binds data to the node. For true multi-node disk resilience, replace local disks with a replicated storage backend.
- CloudNativePG handles PostgreSQL failover, but the operator must remain installed and healthy.
- NodePort is suitable for the current deployment phase. Use LoadBalancer or Ingress/Gateway later when network policy and TLS are finalized.
