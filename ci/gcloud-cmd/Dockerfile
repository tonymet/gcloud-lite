# syntax=docker/dockerfile:1
FROM golang:alpine AS builder
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./
RUN CGO_ENABLED=0 go build -o /gcloud-cmd -tags osusergo,netgo -ldflags "-s -w" .

FROM alpine:latest
RUN apk add --no-cache curl ca-certificates
COPY --from=builder /gcloud-cmd /gcloud-cmd
ENTRYPOINT ["/gcloud-cmd"]
