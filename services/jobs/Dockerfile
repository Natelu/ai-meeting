FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/jobs ./cmd/jobs

FROM alpine:3.21
WORKDIR /app
COPY --from=build /out/jobs /app/jobs
CMD ["/app/jobs"]
