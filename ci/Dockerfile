# build gcloud-cmd
FROM golang:alpine as go-build
COPY *.go go.mod go.sum /app/
WORKDIR /app
RUN go build -o gcloud-cmd -tags osusergo,netgo -ldflags "-s -w" .

# runnable image
FROM alpine
RUN apk add --no-cache zsh jq curl
ADD lite-release.sh /app/
WORKDIR /app
COPY --from=go-build --chmod=700 /app/gcloud-cmd /app/
ENTRYPOINT [ "/app/lite-release.sh" ]