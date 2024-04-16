FROM alpine

RUN apk add --no-cache zsh jq curl
ADD lite-release.sh /app/
WORKDIR /app
ENTRYPOINT [ "/app/lite-release.sh" ]