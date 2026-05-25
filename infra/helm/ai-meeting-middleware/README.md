# AI Meeting Middleware Helm Chart

This chart deploys the Kubernetes middleware stack for AI Meeting.

PostgreSQL is deployed as a CloudNativePG `Cluster`, so the CloudNativePG operator must be installed before this chart.

## Prerequisites

```bash
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.2.yaml
kubectl get deployment -n cnpg-system
```

The Kubernetes cluster also needs:

- A local-path style StorageClass for CloudNativePG PVCs.
- NVIDIA device plugin if Whisper ASR uses GPU.
- Access from the cluster to the existing MinIO endpoint that stores Whisper model files.

## Install

Create an override file:

```yaml
global:
  storageRoot: /mnt/data/k8s/ai-meeting

secrets:
  postgres:
    username: ai_meeting
    password: replace-with-strong-password
    database: ai_meeting
  redis:
    password: replace-with-strong-password
  livekit:
    apiKey: replace-with-key
    apiSecret: replace-with-secret
  grafana:
    adminUser: admin
    adminPassword: replace-with-strong-password
  modelS3:
    accessKey: replace-with-minio-access-key
    secretKey: replace-with-minio-secret-key

modelS3:
  endpoint: http://112.91.142.91:9000
  bucket: meeting-assets
  prefix: models/whisper/large-v3

whisperAsr:
  model: large-v3
  gpuCount: 1
```

Install:

```bash
helm upgrade --install middleware ./infra/helm/ai-meeting-middleware \
  -n ai-meeting --create-namespace \
  -f values-prod.yaml
```

## Verify

```bash
kubectl get pods -n ai-meeting
kubectl get cluster -n ai-meeting
kubectl get svc -n ai-meeting
kubectl logs -n ai-meeting deploy/middleware-ai-meeting-middleware-whisper-asr -c sync-model-from-minio
```

## Application Environment

Use the Node IP plus NodePorts, or in-cluster service names when the app runs in the same cluster.

```env
POSTGRES_DSN=postgres://ai_meeting:<password>@middleware-ai-meeting-middleware-postgres-rw.ai-meeting.svc.cluster.local:5432/ai_meeting?sslmode=disable
REDIS_ADDR=middleware-ai-meeting-middleware-redis-master.ai-meeting.svc.cluster.local:6379
REDIS_SENTINEL_ADDR=middleware-ai-meeting-middleware-redis-sentinel.ai-meeting.svc.cluster.local:26379
LIVEKIT_URL=ws://<node-ip>:30880
ASR_BASE_URL=http://<node-ip>:30901
```
