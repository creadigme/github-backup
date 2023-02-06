#!/bin/bash

# ORG_NAME="[owner]"
# REPO_NAME="[repo name]"
# REPO_PATH="[Repo path]"
# GITEA_URL="http://x.y.z:3000"
# GITEA_USER="[user]"
# GITEA_API_TOKEN="[api token]"

GIT="${GIT:="git"}"

GITEA_VISIBILITY="${GITEA_VISIBILITY:="limited"}"
GITEA_URL_AUTH=$(sed -e "s^//^//$GITEA_API_TOKEN@^" <<<$GITEA_URL)

if [ -z "$GITEA_URL" ]; then
  echo "GITEA_URL cannot be empty (http://x.y.z:3000)."
  exit 101
fi

if [ -z "$GITEA_USER" ]; then
  echo "GITEA_USER cannot be empty."
  exit 102
fi

if [ -z "$GITEA_API_TOKEN" ]; then
  echo "GITEA_API_TOKEN cannot be empty."
  exit 103
fi

if [ -z "$ORG_NAME" ]; then
  echo "ORG_NAME cannot be empty."
  exit 104
fi

if [ -z "$REPO_NAME" ]; then
  echo "REPO_NAME cannot be empty."
  exit 105
fi

if [ -z "$REPO_PATH" ]; then
  echo "REPOPATH cannot be empty."
  exit 106
fi

echo "Mirror2Gitea $GITEA_URL"

# Get or Create Organization
echo "Ensure $ORG_NAME repository"

ORG_RESP=$(curl -s -H "Authorization: token $GITEA_API_TOKEN" -X 'GET' -H 'accept: application/json' $GITEA_URL/api/v1/orgs/$ORG_NAME)
ERROR=$(echo "$ORG_RESP" | jq '.errors?[0]')

if ! [ -z "$ERROR" ] && [ "$ERROR" != "null" ]; then
  # echo "$ERROR"

  # We must create the organisation
  echo "Organisation $ORG_NAME must be created. Creating..."

  ORG_CREATE_RESP=$(curl -s -X 'POST' -H "Authorization: token $GITEA_API_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "description": "'"$ORG_NAME"'",
    "username": "'"$ORG_NAME"'",
    "visibility": "'"$GITEA_VISIBILITY"'"
  }' $GITEA_URL/api/v1/orgs)
  # echo "$ORG_CREATE_RESP"

  ERROR=$(echo "$ORG_CREATE_RESP" | jq '.errors[]? | join(", ")')

  if ! [ -z "$ERROR" ]; then
    echo "$ERROR"
    exit 1
  fi
fi

echo "Ensure ${REPO_NAME} repository for ${ORG_NAME}"

# Get or Create Repository
REPO_RESP=$(curl -s -H "Authorization: token ${GITEA_API_TOKEN}" -X 'GET' -H 'accept: application/json' ${GITEA_URL}/api/v1/repos/${ORG_NAME}/${REPO_NAME})
# echo "$REPO_RESP"
ERROR=$(echo "$REPO_RESP" | jq '.message')

if ! [ -z "$ERROR" ] && [ "$ERROR" != "null" ]; then
  # echo "Repo get error: $ERROR"

  # We must create the repository
  echo "Repository $REPO_NAME must be created. Creating..."

  REPO_CREATE_RESP=$(curl -s -X 'POST' -H "Authorization: token ${GITEA_API_TOKEN}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "description": "'"$REPO_NAME"'",
    "name": "'"$REPO_NAME"'",
    "auto_init": false
  }' ${GITEA_URL}/api/v1/orgs/${ORG_NAME}/repos)
  # echo "$REPO_CREATE_RESP"

  ERROR=$(echo "$REPO_CREATE_RESP" | jq '.message')

  # echo "Repo error: $ERROR";
  if ! [ -z "$ERROR" ] && [ "$ERROR" != "null" ]; then
    echo "$ERROR"
    exit 2
  fi
fi

# Repo URL

REPO_URL="${GITEA_URL_AUTH}/${ORG_NAME}/${REPO_NAME}.git"

echo "Pushing to Gitea... $GITEA_URL/${ORG_NAME}/${REPO_NAME}.git"
(cd $REPO_PATH && ${GIT} push --mirror $REPO_URL)

echo "Done."