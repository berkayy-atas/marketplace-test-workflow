#!/usr/bin/env bash
set -euo pipefail

# Gerekli env değişkenleri:
# ENCRYPTION_PASSWORD, ACTIVATION_CODE
: "${ENCRYPTION_PASSWORD:?ENCRYPTION_PASSWORD missing}"
: "${ACTIVATION_CODE:?ACTIVATION_CODE missing}"

REPO_NAME="$(basename "${GITHUB_REPOSITORY}")"
ENC_FILE_NAME="${REPO_NAME}.tar.zst.enc"

# 1) Arşiv + ZSTD + OpenSSL AES-256
tar -cf repo.tar repo-mirror
zstd -9 repo.tar -o repo.tar.zst

openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in repo.tar.zst \
  -out "$ENC_FILE_NAME" \
  -pass pass:"${ENCRYPTION_PASSWORD}"

UNCOMPRESSED_SIZE="$(stat --printf='%s' repo.tar)"
COMPRESSED_SIZE="$(stat --printf='%s' repo.tar.zst)" || COMPRESSED_SIZE="$(stat --printf='%s' repo.tar.zst 2>/dev/null || echo 0)"

# 2) Aktivasyon Token
RESP_ACT="$(curl -s -w $'\n%{http_code}' -X POST "https://dev.api.file-security.icredible.com/endpoint/activation" \
  -H "Content-Type: application/json" \
  -d "$(jq -nc \
        --arg ac   "$ACTIVATION_CODE" \
        --arg uid  "${GITHUB_REPOSITORY_ID:-}" \
        --arg ip   "${RUNNER_TRACKING_ID:-}" \
        --arg os   "Linux" \
        --arg et   "Workstation" \
        --arg en   "Github Endpoint (${GITHUB_REPOSITORY})" \
        '{activationCode:$ac, uniqueId:$uid, ip:$ip, operatingSystem:$os, endpointType:$et, endpointName:$en}'
      )")"

HTTP_ACT="$(echo "$RESP_ACT" | tail -n1)"
JSON_ACT="$(echo "$RESP_ACT" | head -n -1)"
if [ "$HTTP_ACT" -ne 200 ]; then
  echo "Activation failed: $JSON_ACT"
  exit 1
fi
ENDPOINT_ID="$(echo "$JSON_ACT" | jq -r '.data.endpointId')"
TOKEN="$(echo "$JSON_ACT" | jq -r '.data.token')"

# 3) Git meta (yoksa boş)
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  COMMIT="$(git log -1 --pretty=format:%H)"
  SHORT="$(git log -1 --pretty=format:%h)"
  PARENTS="$(git log -1 --pretty=format:%P)"
  AUTHOR="$(git log -1 --pretty=format:'%an <%ae>')"
  DATE="$(git log -1 --pretty=format:%ad)"
  COMMITTER="$(git log -1 --pretty=format:%cn)"
  MESSAGE="$(git log -1 --pretty=format:'%s%n%b' | tr '\n' ' ')"
else
  COMMIT=""; SHORT=""; PARENTS=""; AUTHOR=""; DATE=""; COMMITTER=""; MESSAGE=""
fi

# Dinamik form alanlarını hazırla
curl_args=(
  -F "MetaData[Event]=${GITHUB_EVENT_NAME}"
  -F "MetaData[Ref]=${GITHUB_REF}"
  -F "MetaData[Actor]=${GITHUB_ACTOR}"
  -F "MetaData[Owner]=${GITHUB_REPOSITORY_OWNER}"
  -F "MetaData[OwnerType]=${GITHUB_EVENT_PATH:+$(jq -r '.repository.owner.type' "$GITHUB_EVENT_PATH" 2>/dev/null || echo '')}"
)
[ -n "$COMMIT" ]    && curl_args+=(-F "MetaData[Commit]=$COMMIT")
[ -n "$SHORT" ]     && curl_args+=(-F "MetaData[CommitShort]=$SHORT")
[ -n "$PARENTS" ]   && curl_args+=(-F "MetaData[Parents]=$PARENTS")
[ -n "$AUTHOR" ]    && curl_args+=(-F "MetaData[Author]=$AUTHOR")
[ -n "$DATE" ]      && curl_args+=(-F "MetaData[Date]=$DATE")
[ -n "$COMMITTER" ] && curl_args+=(-F "MetaData[Committer]=$COMMITTER")
[ -n "$MESSAGE" ]   && curl_args+=(-F "MetaData[Message]=$MESSAGE")

# 4) Yükleme
RESP_UP="$(curl -s -w $'\n%{http_code}' -X POST \
  "https://dev.api.file-security.icredible.com/backup/shield" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@${ENC_FILE_NAME}" \
  -F "Size=${UNCOMPRESSED_SIZE}" \
  -F "CompressedFileSize=${COMPRESSED_SIZE}" \
  -F "Attributes=32" \
  -F "FileName=${GITHUB_REPOSITORY}" \
  -F "CompressionEngine=None" \
  -F "CompressionLevel=NoCompression" \
  -F "FullPath=/${GITHUB_REPOSITORY}/repo.tar.zst" \
  -F "encryptionType=None" \
  -F "RevisionType=1" \
  "${curl_args[@]}")"

HTTP_UP="$(echo "$RESP_UP" | tail -n1)"
JSON_UP="$(echo "$RESP_UP" | head -n -1)"
if [ "$HTTP_UP" -ne 200 ]; then
  echo "Upload failed: $JSON_UP"
  exit 1
fi

RECORD_ID="$(echo "$JSON_UP" | jq -r '.data.recordId')"
DIR_RECORD_ID="$(echo "$JSON_UP" | jq -r '.data.directoryRecordId')"

# 5) Özet bildirimi
{
  echo "✅ Backup completed successfully!"
  echo "--------------------------------------------------"
  echo "**Git Metadata**"
  echo "Repository: ${GITHUB_REPOSITORY}"
  echo "- Owner: ${GITHUB_REPOSITORY_OWNER}"
  echo "- Event: ${GITHUB_EVENT_NAME}"
  echo "- Ref:   ${GITHUB_REF}"
  echo "- Actor: ${GITHUB_ACTOR}"
  if [ -n "$COMMIT" ]; then
    echo "--------------------------------------------------"
    echo "**Upload Metadata**"
    echo "- Commit:      $COMMIT"
    echo "- CommitShort: $SHORT"
    echo "- Parents:     $PARENTS"
    echo "- Author:      $AUTHOR"
    echo "- Date:        $DATE"
    echo "- Committer:   $COMMITTER"
    echo "- Message:     $MESSAGE"
  fi
  echo "--------------------------------------------------"
  echo "**API Response**"
  echo "- File version id: ${RECORD_ID}"
  echo "- Management link: https://dev.management.file-security.icredible.com/dashboard/file-management/${ENDPOINT_ID}/${DIR_RECORD_ID}"
} | sed -e 's/%/%25/g' -e 's/\r/%0D/g' -e 's/\n/%0A/g' | xargs -0 -I{} echo "::notice::{}"
