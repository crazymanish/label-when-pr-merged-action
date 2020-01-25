FROM alpine:3.10.3

LABEL "com.github.actions.name"="Label merged pull requests"
LABEL "com.github.actions.description"="Auto-label pull requests after merged"
LABEL "com.github.actions.icon"="tag"
LABEL "com.github.actions.color"="blue"

LABEL maintainer="Manish Rathi <manishrathi19902013@gmail.com>"

RUN apk add --no-cache bash curl jq

COPY entrypoint.sh /usr/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
