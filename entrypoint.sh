#!/bin/bash
set -e

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

if [[ -z "$LABEL_NAME" ]]; then
  echo "Set the LABEL_NAME env variable."
  exit 1
fi

if [[ -z "$IGNORE_BRANCH_REGEX" ]]; then
  echo "Setting the default IGNORE_BRANCH_REGEX variable value."
  IGNORE_BRANCH_REGEX="(master|release|develop)"
fi

if [[ -z "$IGNORE_BASE_BRANCH" ]]; then
  echo "Setting the default IGNORE_BASE_BRANCH variable value."
  IGNORE_BASE_BRANCH=true
fi

if [[ -z "$IGNORE_CLOSED_PULL_REQUEST" ]]; then
  echo "Setting the default IGNORE_CLOSED_PULL_REQUEST variable value."
  IGNORE_CLOSED_PULL_REQUEST=false
fi

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

ACTION=$(jq --raw-output .action "$GITHUB_EVENT_PATH")
PULL_REQUEST_REF=$(jq --raw-output .pull_request.head.ref "$GITHUB_EVENT_PATH")
IS_PULL_REQUEST_MERGED=$(jq --raw-output .pull_request.merged "$GITHUB_EVENT_PATH")

label_when_pull_request_closed() {
  PULL_REQUEST_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
  PULL_REQUEST_OWNER=$(jq --raw-output .pull_request.head.repo.owner.login "$GITHUB_EVENT_PATH")
  PULL_REQUEST_REPO=$(jq --raw-output .pull_request.head.repo.name "$GITHUB_EVENT_PATH")

  if [[ "$IGNORE_BASE_BRANCH" == "true" ]]; then
    echo "Check: if current closed PR branch is a base-branch of another PR."
    PULLS_AS_BASE_BRANCH=$(
  		curl -XGET -fsSL \
  			-H "${AUTH_HEADER}" \
  			-H "${API_HEADER}" \
  			"${URI}/repos/${PULL_REQUEST_OWNER}/${PULL_REQUEST_REPO}/pulls?state=open&base=${PULL_REQUEST_REF}"
  	)
  	IS_BASE_BRANCH=$(echo "$PULLS_AS_BASE_BRANCH" | jq 'has(0)')

    # Do not add label if It is a base branch of another pull request
    if [[ "$IS_BASE_BRANCH" == "true" ]]; then
  		NUMBER=$(echo "$PULLS_AS_BASE_BRANCH" | jq '.[0].number')
  		echo "Ignoring - ${PULL_REQUEST_REF} is the base branch of PR #${NUMBER} for ${PULL_REQUEST_OWNER}/${PULL_REQUEST_REPO}."
  		exit 0
  	fi
  fi

  echo "Labeling pull request"
  curl -sSL \
    -H "${AUTH_HEADER}" \
    -H "${API_HEADER}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"labels\":[\"${LABEL_NAME}\"]}" \
    "${URI}/repos/${GITHUB_REPOSITORY}/issues/${PULL_REQUEST_NUMBER}/labels"
}

if [[ "$PULL_REQUEST_REF" =~ $IGNORE_BRANCH_REGEX ]]; then
  echo "Ignoring pull-request branch: $PULL_REQUEST_REF using REGEX: $IGNORE_BRANCH_REGEX"
  exit 0
fi

if [[ "$ACTION" == "closed" ]] && ([[ "$IS_PULL_REQUEST_MERGED" == "true" ]] || [[ "$IGNORE_CLOSED_PULL_REQUEST" == "false" ]]); then
  label_when_pull_request_closed
else
  echo "Ignoring pull-request event - action: $ACTION, merged: $IS_PULL_REQUEST_MERGED"
  exit 0
fi
