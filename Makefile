SHELL := /bin/bash

.PHONY: test test-api test-jobs test-web build-web dev-web dev-api compose-local compose-pilot

test: test-api test-jobs test-web

test-api:
	cd services/api && go test ./...

test-jobs:
	cd services/jobs && go test ./...

test-web:
	cd apps/web && npm test

build-web:
	cd apps/web && npm run build

dev-web:
	cd apps/web && npm run dev

dev-api:
	cd services/api && API_ADDR=:8080 go run ./cmd/api

compose-local:
	docker compose --env-file .env.example -f infra/docker/docker-compose.local.yml up -d

compose-pilot:
	docker compose --env-file .env.example -f infra/docker/docker-compose.pilot.yml up -d
