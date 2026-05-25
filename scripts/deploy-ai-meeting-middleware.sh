#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="ai-meeting"
DATA_ROOT=""
BIND_IP="0.0.0.0"
PUBLIC_HOST=""
ASR_GPU="0"
ASR_MODEL="large-v3"
ASR_MODELSCOPE_MODEL=""
LLM_BASE_URL=""
LLM_MODEL=""
LLM_API_KEY=""
WITH_OBSERVABILITY="true"
PULL_IMAGES="true"
CLEAN_FIRST="true"
COMPOSE_PROJECT_NAME=""

usage() {
  cat <<'USAGE'
Deploy AI Meeting middleware with Docker Compose.

Usage:
  deploy-ai-meeting-middleware.sh [options]

Options:
  --app-name NAME                 App directory name under data root parent. Default: ai-meeting
  --project-name NAME             Docker Compose project name / container name prefix. Default: middleware
  --data-root PATH                Data/config root. Default: /mnt/data/{app_name}
  --bind-ip IP                    Host bind IP for exposed ports. Default: 0.0.0.0
  --public-host HOST              Public IP/domain returned in generated connection strings.
                                  Default: first host IP if detectable, otherwise localhost
  --asr-gpu GPU_ID                GPU id for Whisper ASR. Default: 0
  --asr-model MODEL               Whisper model. Default: large-v3
  --asr-modelscope-model MODEL_ID ModelScope faster-whisper model id.
                                  Default: auto-map from --asr-model
  --llm-base-url URL              Cloud model OpenAI-compatible base URL, e.g. https://.../v1
  --llm-model MODEL               Cloud model name
  --llm-api-key KEY               Cloud model API key
  --no-observability              Skip Prometheus, Grafana, and Loki
  --no-clean                      Do not run docker compose down before starting
  --no-pull                       Skip docker compose pull
  -h, --help                      Show this help

Examples:
  sudo bash deploy-ai-meeting-middleware.sh
  sudo bash deploy-ai-meeting-middleware.sh --data-root /data/ai-meeting --public-host 10.0.0.12
  sudo bash deploy-ai-meeting-middleware.sh --llm-base-url https://your-provider/v1 --llm-model your-model --llm-api-key sk-xxx
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --project-name)
      COMPOSE_PROJECT_NAME="$2"
      shift 2
      ;;
    --data-root)
      DATA_ROOT="$2"
      shift 2
      ;;
    --bind-ip)
      BIND_IP="$2"
      shift 2
      ;;
    --public-host)
      PUBLIC_HOST="$2"
      shift 2
      ;;
    --asr-gpu)
      ASR_GPU="$2"
      shift 2
      ;;
    --asr-model)
      ASR_MODEL="$2"
      shift 2
      ;;
    --asr-modelscope-model)
      ASR_MODELSCOPE_MODEL="$2"
      shift 2
      ;;
    --llm-base-url)
      LLM_BASE_URL="$2"
      shift 2
      ;;
    --llm-model)
      LLM_MODEL="$2"
      shift 2
      ;;
    --llm-api-key)
      LLM_API_KEY="$2"
      shift 2
      ;;
    --no-observability)
      WITH_OBSERVABILITY="false"
      shift
      ;;
    --no-clean)
      CLEAN_FIRST="false"
      shift
      ;;
    --no-pull)
      PULL_IMAGES="false"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$DATA_ROOT" ]]; then
  DATA_ROOT="/mnt/data/${APP_NAME}"
fi

if [[ -z "$COMPOSE_PROJECT_NAME" ]]; then
  COMPOSE_PROJECT_NAME="middleware"
fi

if [[ -z "$ASR_MODELSCOPE_MODEL" ]]; then
  case "$ASR_MODEL" in
    large|large-v3)
      ASR_MODELSCOPE_MODEL="Systran/faster-whisper-large-v3"
      ;;
    large-v2)
      ASR_MODELSCOPE_MODEL="Systran/faster-whisper-large-v2"
      ;;
    distil-large-v3)
      ASR_MODELSCOPE_MODEL="Systran/faster-distil-whisper-large-v3"
      ;;
    large-v3-turbo|turbo)
      ASR_MODELSCOPE_MODEL="Tiandong/faster-whisper-large-v3-turbo-ct2"
      ;;
    *)
      ASR_MODELSCOPE_MODEL="Systran/faster-whisper-${ASR_MODEL}"
      ;;
  esac
fi

if [[ -z "$PUBLIC_HOST" ]]; then
  PUBLIC_HOST="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  PUBLIC_HOST="${PUBLIC_HOST:-localhost}"
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd docker
require_cmd openssl

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required: docker compose version" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not reachable. Run as a user with Docker access or use sudo." >&2
  exit 1
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi -L >/dev/null || echo "WARNING: nvidia-smi failed on host." >&2
else
  echo "WARNING: nvidia-smi not found on host." >&2
fi

if ! docker info 2>/dev/null | grep -qi nvidia; then
  echo "WARNING: Docker NVIDIA runtime not detected. Install NVIDIA Container Toolkit before starting Whisper ASR GPU service." >&2
fi

CONFIG_DIR="${DATA_ROOT}/config"
CREDENTIALS_FILE="${CONFIG_DIR}/credentials.env"
ENV_FILE="${CONFIG_DIR}/.env"
COMPOSE_FILE="${CONFIG_DIR}/docker-compose.yml"
LIVEKIT_CONFIG="${CONFIG_DIR}/livekit.yaml"
PROMETHEUS_CONFIG="${CONFIG_DIR}/prometheus.yml"
LOKI_CONFIG="${CONFIG_DIR}/loki-config.yml"

if [[ "$CLEAN_FIRST" == "true" && -f "$COMPOSE_FILE" ]]; then
  echo "Pre-cleaning previously started containers before port detection..."
  if [[ -f "$ENV_FILE" ]]; then
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down --remove-orphans || true
    docker compose -p "${APP_NAME}-middleware" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down --remove-orphans || true
    docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down --remove-orphans || true
  else
    docker compose -f "$COMPOSE_FILE" down --remove-orphans || true
    docker compose -p "${APP_NAME}-middleware" -f "$COMPOSE_FILE" down --remove-orphans || true
    docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" down --remove-orphans || true
  fi
fi

ALLOCATED_PORTS=""

port_reserved() {
  case " ${ALLOCATED_PORTS} " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

port_in_use() {
  local port="$1"
  local proto="${2:-tcp}"
  if command -v ss >/dev/null 2>&1; then
    if [[ "$proto" == "udp" ]]; then
      ss -H -lun 2>/dev/null | awk '{print $5}' | grep -Eq "[:.]${port}$"
    else
      ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
    fi
    return $?
  fi
  if command -v netstat >/dev/null 2>&1; then
    if [[ "$proto" == "udp" ]]; then
      netstat -lun 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
    else
      netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
    fi
    return $?
  fi
  return 1
}

reserve_port() {
  local base_port="$1"
  local proto="$2"
  local var_name="$3"
  local port="$base_port"
  while port_reserved "$port" || port_in_use "$port" "$proto"; do
    echo "Port ${port}/${proto} is in use, trying $((port + 1))..." >&2
    port=$((port + 1))
  done
  ALLOCATED_PORTS="${ALLOCATED_PORTS} ${port}"
  printf -v "$var_name" '%s' "$port"
}

reserve_port 5432 tcp POSTGRES_PORT
reserve_port 6379 tcp REDIS_PORT
reserve_port 9000 tcp MINIO_API_PORT
reserve_port 9002 tcp MINIO_CONSOLE_PORT
reserve_port 7880 tcp LIVEKIT_WS_PORT
reserve_port 7881 tcp LIVEKIT_TCP_PORT
reserve_port 7882 udp LIVEKIT_UDP_PORT
reserve_port 9001 tcp ASR_PORT
reserve_port 9090 tcp PROMETHEUS_PORT
reserve_port 3001 tcp GRAFANA_PORT
reserve_port 3100 tcp LOKI_PORT

mkdir -p \
  "${CONFIG_DIR}" \
  "${DATA_ROOT}/postgres" \
  "${DATA_ROOT}/redis" \
  "${DATA_ROOT}/minio" \
  "${DATA_ROOT}/whisper/cache" \
  "${DATA_ROOT}/whisper/modelscope" \
  "${DATA_ROOT}/grafana" \
  "${DATA_ROOT}/loki"

chmod 700 "${CONFIG_DIR}"
chown -R 472:472 "${DATA_ROOT}/grafana" 2>/dev/null || echo "WARNING: failed to chown Grafana data dir; run script with sudo if Grafana reports permission errors." >&2
chown -R 10001:10001 "${DATA_ROOT}/loki" 2>/dev/null || echo "WARNING: failed to chown Loki data dir; run script with sudo if Loki reports permission errors." >&2

rand_hex() {
  openssl rand -hex "${1:-24}"
}

rand_alnum() {
  local length="${1:-32}"
  local value=""
  while [[ "${#value}" -lt "$length" ]]; do
    value="${value}$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9')"
  done
  printf '%s' "${value:0:length}"
}

if [[ ! -f "$CREDENTIALS_FILE" ]]; then
  POSTGRES_PASSWORD="$(rand_hex 24)"
  REDIS_PASSWORD="$(rand_hex 24)"
  MINIO_ROOT_USER="minio$(rand_alnum 12)"
  MINIO_ROOT_PASSWORD="$(rand_hex 24)"
  LIVEKIT_API_KEY="lk$(rand_alnum 20)"
  LIVEKIT_API_SECRET="$(rand_hex 32)"
  GRAFANA_ADMIN_PASSWORD="$(rand_hex 20)"

  cat > "$CREDENTIALS_FILE" <<EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
LIVEKIT_API_KEY=${LIVEKIT_API_KEY}
LIVEKIT_API_SECRET=${LIVEKIT_API_SECRET}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
EOF
  chmod 600 "$CREDENTIALS_FILE"
fi

# shellcheck disable=SC1090
source "$CREDENTIALS_FILE"

cat > "$ENV_FILE" <<EOF
APP_NAME=${APP_NAME}
DATA_ROOT=${DATA_ROOT}
BIND_IP=${BIND_IP}
PUBLIC_HOST=${PUBLIC_HOST}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}

POSTGRES_PORT=${POSTGRES_PORT}
REDIS_PORT=${REDIS_PORT}
MINIO_API_PORT=${MINIO_API_PORT}
MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT}
LIVEKIT_WS_PORT=${LIVEKIT_WS_PORT}
LIVEKIT_TCP_PORT=${LIVEKIT_TCP_PORT}
LIVEKIT_UDP_PORT=${LIVEKIT_UDP_PORT}
ASR_PORT=${ASR_PORT}
PROMETHEUS_PORT=${PROMETHEUS_PORT}
GRAFANA_PORT=${GRAFANA_PORT}
LOKI_PORT=${LOKI_PORT}

POSTGRES_DB=ai_meeting
POSTGRES_USER=ai_meeting
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DSN=postgres://ai_meeting:${POSTGRES_PASSWORD}@postgres:5432/ai_meeting?sslmode=disable

REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_ADDR=redis:6379
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0

MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
S3_ENDPOINT=http://minio:9000
S3_BUCKET=meeting-assets
S3_REGION=local
S3_ACCESS_KEY_ID=${MINIO_ROOT_USER}
S3_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD}
S3_PREFIX=tenant-a/

LIVEKIT_URL=ws://livekit:7880
LIVEKIT_PUBLIC_URL=ws://${PUBLIC_HOST}:${LIVEKIT_WS_PORT}
LIVEKIT_API_KEY=${LIVEKIT_API_KEY}
LIVEKIT_API_SECRET=${LIVEKIT_API_SECRET}

ASR_GPU=${ASR_GPU}
ASR_MODEL=${ASR_MODEL}
ASR_MODELSCOPE_MODEL=${ASR_MODELSCOPE_MODEL}
ASR_CONTAINER_MODEL=/models/${ASR_MODEL}
ASR_BASE_URL=http://whisper-asr:9000
ASR_PUBLIC_URL=http://${PUBLIC_HOST}:${ASR_PORT}

LLM_BASE_URL=${LLM_BASE_URL}
LLM_MODEL=${LLM_MODEL}
LLM_API_KEY=${LLM_API_KEY}

GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
EOF
chmod 600 "$ENV_FILE"

cat > "$LIVEKIT_CONFIG" <<EOF
port: ${LIVEKIT_WS_PORT}
bind_addresses:
  - ""
rtc:
  tcp_port: ${LIVEKIT_TCP_PORT}
  udp_port: ${LIVEKIT_UDP_PORT}
  use_external_ip: true
keys:
  ${LIVEKIT_API_KEY}: ${LIVEKIT_API_SECRET}
logging:
  level: info
room:
  auto_create: true
webhook:
  api_key: ${LIVEKIT_API_KEY}
  urls:
    - http://api:8080/webhooks/livekit
EOF

cat > "$PROMETHEUS_CONFIG" <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["prometheus:9090"]
  - job_name: ai-meeting-api
    static_configs:
      - targets: ["host.docker.internal:8080"]
  - job_name: ai-meeting-jobs
    static_configs:
      - targets: ["host.docker.internal:8090"]
EOF

cat > "$LOKI_CONFIG" <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  allow_structured_metadata: false
EOF

cat > "$COMPOSE_FILE" <<'EOF'
services:
  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_DB: ai_meeting
      POSTGRES_USER: ai_meeting
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "${BIND_IP}:${POSTGRES_PORT}:5432"
    volumes:
      - "${DATA_ROOT}/postgres:/var/lib/postgresql/data"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ai_meeting -d ai_meeting"]
      interval: 10s
      timeout: 5s
      retries: 10

  redis:
    image: redis:7
    restart: unless-stopped
    environment:
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    command: ["redis-server", "--appendonly", "yes", "--requirepass", "${REDIS_PASSWORD}"]
    ports:
      - "${BIND_IP}:${REDIS_PORT}:6379"
    volumes:
      - "${DATA_ROOT}/redis:/data"
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a \"$${REDIS_PASSWORD}\" ping | grep PONG"]
      interval: 10s
      timeout: 5s
      retries: 10

  minio:
    image: minio/minio:RELEASE.2025-04-22T22-12-26Z
    restart: unless-stopped
    command: ["server", "/data", "--console-address", ":9001"]
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    ports:
      - "${BIND_IP}:${MINIO_API_PORT}:9000"
      - "${BIND_IP}:${MINIO_CONSOLE_PORT}:9001"
    volumes:
      - "${DATA_ROOT}/minio:/data"
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 10s
      timeout: 5s
      retries: 10

  minio-init:
    image: minio/mc:latest
    depends_on:
      minio:
        condition: service_healthy
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
      S3_BUCKET: ${S3_BUCKET}
    entrypoint:
      - /bin/sh
      - -c
      - |
        mc alias set local http://minio:9000 "$${MINIO_ROOT_USER}" "$${MINIO_ROOT_PASSWORD}"
        mc mb -p "local/$${S3_BUCKET}" || true
        mc anonymous set none "local/$${S3_BUCKET}" || true
    restart: "no"

  livekit:
    image: livekit/livekit-server:latest
    restart: unless-stopped
    command: ["--config", "/etc/livekit.yaml"]
    ports:
      - "${BIND_IP}:${LIVEKIT_WS_PORT}:${LIVEKIT_WS_PORT}"
      - "${BIND_IP}:${LIVEKIT_TCP_PORT}:${LIVEKIT_TCP_PORT}"
      - "${BIND_IP}:${LIVEKIT_UDP_PORT}:${LIVEKIT_UDP_PORT}/udp"
    volumes:
      - "${DATA_ROOT}/config/livekit.yaml:/etc/livekit.yaml:ro"

  asr-model-download:
    image: python:3.11-slim
    restart: "no"
    environment:
      ASR_MODEL: ${ASR_MODEL}
      ASR_MODELSCOPE_MODEL: ${ASR_MODELSCOPE_MODEL}
      PIP_INDEX_URL: https://pypi.tuna.tsinghua.edu.cn/simple
      PIP_DISABLE_PIP_VERSION_CHECK: "1"
      PYTHONUNBUFFERED: "1"
    volumes:
      - "${DATA_ROOT}/whisper/modelscope:/models"
    command:
      - /bin/sh
      - -lc
      - |
        set -e
        if [ -f "/models/$${ASR_MODEL}/model.bin" ]; then
          echo "Model already exists: /models/$${ASR_MODEL}"
          exit 0
        fi
        echo "Installing modelscope CLI from $${PIP_INDEX_URL}..."
        python -m pip install --no-cache-dir -U modelscope
        echo "Downloading $${ASR_MODELSCOPE_MODEL} to /models/$${ASR_MODEL} from ModelScope..."
        modelscope download --model "$${ASR_MODELSCOPE_MODEL}" --local_dir "/models/$${ASR_MODEL}"
        echo "ModelScope download completed: /models/$${ASR_MODEL}"

  whisper-asr:
    image: registry.cn-wulanchabu.aliyuncs.com/docker-mr-ali/onerahmet.openai-whisper-asr-webservice:latest-gpu
    restart: unless-stopped
    runtime: nvidia
    depends_on:
      asr-model-download:
        condition: service_completed_successfully
    environment:
      NVIDIA_VISIBLE_DEVICES: ${ASR_GPU}
      NVIDIA_DRIVER_CAPABILITIES: compute,utility
      ASR_ENGINE: faster_whisper
      ASR_MODEL: ${ASR_CONTAINER_MODEL}
      ASR_DEVICE: cuda
      ASR_MODEL_PATH: /models
    ports:
      - "${BIND_IP}:${ASR_PORT}:9000"
    volumes:
      - "${DATA_ROOT}/whisper/cache:/root/.cache"
      - "${DATA_ROOT}/whisper/modelscope:/models:ro"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ["${ASR_GPU}"]
              capabilities: ["gpu"]
    healthcheck:
      test: ["CMD-SHELL", "python - <<'PY'\nimport urllib.request\nurllib.request.urlopen('http://127.0.0.1:9000/docs', timeout=5)\nPY"]
      interval: 30s
      timeout: 10s
      retries: 20

EOF

if [[ "$WITH_OBSERVABILITY" == "true" ]]; then
  cat >> "$COMPOSE_FILE" <<'EOF'

  prometheus:
    image: prom/prometheus:v3.0.1
    restart: unless-stopped
    ports:
      - "${BIND_IP}:${PROMETHEUS_PORT}:9090"
    volumes:
      - "${DATA_ROOT}/config/prometheus.yml:/etc/prometheus/prometheus.yml:ro"
    extra_hosts:
      - "host.docker.internal:host-gateway"

  grafana:
    image: grafana/grafana:11.4.0
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
    ports:
      - "${BIND_IP}:${GRAFANA_PORT}:3000"
    volumes:
      - "${DATA_ROOT}/grafana:/var/lib/grafana"

  loki:
    image: grafana/loki:3.3.2
    restart: unless-stopped
    command: ["-config.file=/etc/loki/local-config.yaml"]
    ports:
      - "${BIND_IP}:${LOKI_PORT}:3100"
    volumes:
      - "${DATA_ROOT}/config/loki-config.yml:/etc/loki/local-config.yaml:ro"
      - "${DATA_ROOT}/loki:/loki"
EOF
fi

echo "Deployment directory: ${DATA_ROOT}"
echo "Compose file: ${COMPOSE_FILE}"

compose_cmd() {
  docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

health_host() {
  if [[ "$BIND_IP" == "0.0.0.0" || "$BIND_IP" == "::" ]]; then
    printf '127.0.0.1'
  else
    printf '%s' "$BIND_IP"
  fi
}

show_service_logs() {
  local service="$1"
  echo "---- ${service} recent logs ----" >&2
  compose_cmd logs --tail=100 "$service" >&2 || true
  echo "---- end ${service} logs ----" >&2
}

service_failed() {
  local service="$1"
  local container_id state exit_code
  container_id="$(compose_cmd ps -a -q "$service" 2>/dev/null || true)"
  [[ -n "$container_id" ]] || return 1
  state="$(docker inspect -f '{{.State.Status}}' "$container_id" 2>/dev/null || true)"
  exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$container_id" 2>/dev/null || true)"
  [[ "$state" == "exited" && "$exit_code" != "0" ]] || [[ "$state" == "dead" ]]
}

wait_for_completed_service() {
  local service="$1"
  local timeout="${2:-900}"
  local log_interval="${3:-30}"
  local start now container_id state exit_code last_log
  start="$(date +%s)"
  last_log="$start"
  echo "Checking ${service} completion..."
  while true; do
    container_id="$(compose_cmd ps -a -q "$service" 2>/dev/null || true)"
    if [[ -n "$container_id" ]]; then
      state="$(docker inspect -f '{{.State.Status}}' "$container_id" 2>/dev/null || true)"
      exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$container_id" 2>/dev/null || true)"
      if [[ "$state" == "exited" && "$exit_code" == "0" ]]; then
        echo "OK: ${service} completed"
        return 0
      fi
      if [[ "$state" == "exited" || "$state" == "dead" ]]; then
        echo "FAILED: ${service} exited with code ${exit_code}" >&2
        show_service_logs "$service"
        return 1
      fi
    fi
    now="$(date +%s)"
    if (( now - last_log >= log_interval )); then
      echo "Still waiting for ${service}; recent logs:"
      compose_cmd logs --tail=20 "$service" || true
      last_log="$now"
    fi
    if (( now - start >= timeout )); then
      echo "FAILED: ${service} did not complete within ${timeout}s" >&2
      show_service_logs "$service"
      return 1
    fi
    sleep 5
  done
}

wait_for_tcp_service() {
  local service="$1"
  local label="$2"
  local port="$3"
  local timeout="${4:-180}"
  local host start now
  host="$(health_host)"
  start="$(date +%s)"
  echo "Checking ${label} on ${host}:${port}..."
  while true; do
    if (echo >"/dev/tcp/${host}/${port}") >/dev/null 2>&1; then
      echo "OK: ${label} is reachable on ${host}:${port}"
      return 0
    fi
    if service_failed "$service"; then
      echo "FAILED: ${label} container exited before port ${port} became reachable" >&2
      show_service_logs "$service"
      return 1
    fi
    now="$(date +%s)"
    if (( now - start >= timeout )); then
      echo "FAILED: ${label} not reachable on ${host}:${port} within ${timeout}s" >&2
      show_service_logs "$service"
      return 1
    fi
    sleep 5
  done
}

if [[ "$CLEAN_FIRST" == "true" ]]; then
  echo "Cleaning previously started containers for legacy project name: config"
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down --remove-orphans || true
  echo "Cleaning previously started containers for legacy project name: ${APP_NAME}-middleware"
  docker compose -p "${APP_NAME}-middleware" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down --remove-orphans || true
  echo "Cleaning previously started containers for project: ${COMPOSE_PROJECT_NAME}"
  docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down --remove-orphans || true
fi

if [[ "$PULL_IMAGES" == "true" ]]; then
  compose_cmd pull
fi

compose_cmd up -d

echo
echo "Running deployment health checks..."
wait_for_tcp_service postgres "PostgreSQL" "$POSTGRES_PORT" 180
wait_for_tcp_service redis "Redis" "$REDIS_PORT" 180
wait_for_tcp_service minio "MinIO API" "$MINIO_API_PORT" 180
wait_for_completed_service minio-init 180
wait_for_tcp_service livekit "LiveKit WS" "$LIVEKIT_WS_PORT" 180
wait_for_tcp_service livekit "LiveKit RTC TCP" "$LIVEKIT_TCP_PORT" 180
wait_for_completed_service asr-model-download 1800
wait_for_tcp_service whisper-asr "Whisper ASR" "$ASR_PORT" 900
if [[ "$WITH_OBSERVABILITY" == "true" ]]; then
  wait_for_tcp_service prometheus "Prometheus" "$PROMETHEUS_PORT" 180
  wait_for_tcp_service grafana "Grafana" "$GRAFANA_PORT" 180
  wait_for_tcp_service loki "Loki" "$LOKI_PORT" 180
fi

echo
echo "Current service status:"
compose_cmd ps

cat <<EOF

AI Meeting middleware deployed.

Files:
  Compose:      ${COMPOSE_FILE}
  Env:          ${ENV_FILE}
  Credentials:  ${CREDENTIALS_FILE}
  Data root:    ${DATA_ROOT}

Accounts and connection values:
  PostgreSQL:
    Host:       ${PUBLIC_HOST}
    Port:       ${POSTGRES_PORT}
    Database:   ai_meeting
    User:       ai_meeting
    Password:   ${POSTGRES_PASSWORD}
    DSN:        postgres://ai_meeting:${POSTGRES_PASSWORD}@${PUBLIC_HOST}:${POSTGRES_PORT}/ai_meeting?sslmode=disable

  Redis:
    Host:       ${PUBLIC_HOST}
    Port:       ${REDIS_PORT}
    Password:   ${REDIS_PASSWORD}
    URL:        redis://:${REDIS_PASSWORD}@${PUBLIC_HOST}:${REDIS_PORT}/0

  MinIO / S3:
    API:        http://${PUBLIC_HOST}:${MINIO_API_PORT}
    Console:    http://${PUBLIC_HOST}:${MINIO_CONSOLE_PORT}
    Bucket:     meeting-assets
    AccessKey:  ${MINIO_ROOT_USER}
    SecretKey:  ${MINIO_ROOT_PASSWORD}

  LiveKit:
    URL:        ws://${PUBLIC_HOST}:${LIVEKIT_WS_PORT}
    API Key:    ${LIVEKIT_API_KEY}
    API Secret: ${LIVEKIT_API_SECRET}
    RTC TCP:    ${PUBLIC_HOST}:${LIVEKIT_TCP_PORT}
    RTC UDP:    ${PUBLIC_HOST}:${LIVEKIT_UDP_PORT}/udp

  Whisper ASR GPU:
    URL:        http://${PUBLIC_HOST}:${ASR_PORT}
    GPU:        ${ASR_GPU}
    Model:      ${ASR_MODEL}
    ModelScope: ${ASR_MODELSCOPE_MODEL}
    Auth:       none

  Cloud LLM OpenAI-compatible:
    Base URL:   ${LLM_BASE_URL:-not configured}
    Model:      ${LLM_MODEL:-not configured}
    API Key:    ${LLM_API_KEY:-not configured}

  Grafana:
    URL:        http://${PUBLIC_HOST}:${GRAFANA_PORT}
    User:       admin
    Password:   ${GRAFANA_ADMIN_PASSWORD}

  Prometheus:
    URL:        http://${PUBLIC_HOST}:${PROMETHEUS_PORT}
    Auth:       none

  Loki:
    URL:        http://${PUBLIC_HOST}:${LOKI_PORT}
    Auth:       none

Recommended app env:
  POSTGRES_DSN=postgres://ai_meeting:${POSTGRES_PASSWORD}@${PUBLIC_HOST}:${POSTGRES_PORT}/ai_meeting?sslmode=disable
  REDIS_URL=redis://:${REDIS_PASSWORD}@${PUBLIC_HOST}:${REDIS_PORT}/0
  REDIS_ADDR=${PUBLIC_HOST}:${REDIS_PORT}
  S3_ENDPOINT=http://${PUBLIC_HOST}:${MINIO_API_PORT}
  S3_BUCKET=meeting-assets
  S3_ACCESS_KEY_ID=${MINIO_ROOT_USER}
  S3_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD}
  LIVEKIT_URL=ws://${PUBLIC_HOST}:${LIVEKIT_WS_PORT}
  LIVEKIT_API_KEY=${LIVEKIT_API_KEY}
  LIVEKIT_API_SECRET=${LIVEKIT_API_SECRET}
  ASR_BASE_URL=http://${PUBLIC_HOST}:${ASR_PORT}
  LLM_BASE_URL=${LLM_BASE_URL:-<cloud-openai-compatible-base-url>}
  LLM_MODEL=${LLM_MODEL:-<cloud-model-name>}
  LLM_API_KEY=${LLM_API_KEY:-<cloud-api-key>}

Security note:
  Ports are bound to ${BIND_IP}. Restrict PostgreSQL, Redis, MinIO, ASR, Prometheus, Grafana, and Loki with firewall/security groups.
  LiveKit needs ${LIVEKIT_WS_PORT}/tcp, ${LIVEKIT_TCP_PORT}/tcp, and ${LIVEKIT_UDP_PORT}/udp reachable by clients.
EOF
