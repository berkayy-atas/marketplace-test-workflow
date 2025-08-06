#!/usr/bin/env bash
set -euo pipefail

# Beklenen env değişkenleri:
: "${ENCRYPTION_PASSWORD:?ENCRYPTION_PASSWORD missing}"
: "${ACTIVATION_CODE:?ACTIVATION_CODE missing}"

# GitHub context (env'den gelir, yoksa defaultları dene)
REPOSITORY_ID="${REPOSITORY_ID:-${GITHUB_REPOSITORY_ID:-}}"
REPOSITORY="${REPOSITORY:-${GITHUB_REPOSITORY:-}}"
EVENT_NAME="${EVENT_NAME:-${GITHUB_EVENT_NAME:-}}"
REF="${REF:-${GITHUB_REF:-}}"
ACTOR="${ACTOR:-${GITHUB_ACTOR:-}}"
REPOSITORY_OWNER="${REPOSITORY_OWNER:-${GITHUB_REPOSITORY_OWNER:-}}"

REPO_NAME="$(basename "${REPOSITORY:-repo}")"
ENC_FILE_NAME="${REPO_NAME}.tar.zst.enc"

# 1) Arşivle, zstd ile sıkıştır, OpenSSL AES-256 ile şifrele
tar -cf repo.tar repo-mirror
zstd -9 repo.tar -o repo.tar.zst

openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in repo.tar.zst \
  -out "$ENC_FILE_NAME" \
  -pass pass:"${ENCRYPTION_PASSWORD}"

UNCOMPRESSED_SIZE="$(stat --printf='%s' repo.tar)"
COMPRESSED_SIZE="$(stat --printf='%s' "${ENC_FILE_NAME}")"

# 2) Aktivasyon (token alma)
OWNER_TYPE=""
if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  OWNER_TYPE="$(jq -r '.repository.owner.type // empty' "${GITHUB_EVENT_PATH}")"
fi

ACTIVATION_PAYLOAD="$(jq -nc \
  --arg ac   "$ACTIVATION_CODE" \
  --arg uid  "${REPOSITORY_ID}" \
  --arg ip   "" \
  --arg os   "Linux" \
  --arg et   "Workstation" \
  --arg en   "Github Endpoint (${REPOSITORY})" \
  '{activationCode:$ac, uniqueId:$uid, ip:$ip, operatingSystem:$os, endpointType:$et, endpointName:$en}'
)"

RESP_ACT="$(curl -s -w $'\n%{http_code}' -X POST \
  "https://dev.api.file-security.icredible.com/endpoint/activation" \
  -H "Content-Type: application/json" \
  -d "${ACTIVATION_PAYLOAD}"
)"

HTTP_ACT="$(echo "$RESP_ACT" | tail -n1)"
JSON_ACT="$(echo "$RESP_ACT" | head -n -1)"
if [ "$HTTP_ACT" -ne 200 ]; then
  echo "Activation failed: $JSON_ACT"
  exit 1
fi

ENDPOINT_ID="$(echo "$JSON_ACT" | jq -r '.data.endpointId')"
TOKEN="$(echo "$JSON_ACT" | jq -r '.data.token')"

# 3) Git metadata
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

# 4) Upload form argümanları
declare -a CURL_ARGS=(
  -F "MetaData[Event]=${EVENT_NAME}"
  -F "MetaData[Ref]=${REF}"
  -F "MetaData[Actor]=${ACTOR}"
  -F "MetaData[Owner]=${REPOSITORY_OWNER}"
)
[ -n "$OWNER_TYPE" ] && CURL_ARGS+=(-F "MetaData[OwnerType]=${OWNER_TYPE}")
[ -n "$COMMIT" ]    && CURL_ARGS+=(-F "MetaData[Commit]=$COMMIT")
[ -n "$SHORT" ]     && CURL_ARGS+=(-F "MetaData[CommitShort]=$SHORT")
[ -n "$PARENTS" ]   && CURL_ARGS+=(-F "MetaData[Parents]=$PARENTS")
[ -n "$AUTHOR" ]    && CURL_ARGS+=(-F "MetaData[Author]=$AUTHOR")
[ -n "$DATE" ]      && CURL_ARGS+=(-F "MetaData[Date]=$DATE")
[ -n "$COMMITTER" ] && CURL_ARGS+=(-F "MetaData[Committer]=$COMMITTER")
[ -n "$MESSAGE" ]   && CURL_ARGS+=(-F "MetaData[Message]=$MESSAGE")

# 5) Yükleme (shield)
RESP_UP="$(curl -s -w $'\n%{http_code}' -X POST \
  "https://dev.api.file-security.icredible.com/backup/shield" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@${ENC_FILE_NAME}" \
  -F "Size=${UNCOMPRESSED_SIZE}" \
  -F "CompressedFileSize=${COMPRESSED_SIZE}" \
  -F "Attributes=32" \
  -F "FileName=${REPOSITORY}" \
  -F "CompressionEngine=None" \
  -F "CompressionLevel=NoCompression" \
  -F "FullPath=/${REPOSITORY}/repo.tar.zst" \
  -F "encryptionType=None" \
  -F "RevisionType=1" \
  "${CURL_ARGS[@]}"
)"

HTTP_UP="$(echo "$RESP_UP" | tail -n1)"
JSON_UP="$(echo "$RESP_UP" | head -n -1)"
if [ "$HTTP_UP" -ne 200 ]; then
  echo "Upload failed: $JSON_UP"
  exit 1
fi

RECORD_ID="$(echo "$JSON_UP" | jq -r '.data.recordId')"
DIR_RECORD_ID="$(echo "$JSON_UP" | jq -r '.data.directoryRecordId')"

# 6) (İSTEDİĞİN FORMATLA) Özet metni .sh içinde bas
UPLOAD_METADATA=""
if [ -n "$COMMIT" ]; then
  UPLOAD_METADATA="$(cat <<EOF
        --------------------------------------------------
        **Upload Metadata**
        - Commit:      ${COMMIT}
        - CommitShort: ${SHORT}
        - Parents:     ${PARENTS}
        - Author:      ${AUTHOR}
        - Date:        ${DATE}
        - Committer:   ${COMMITTER}
        - Message:     ${MESSAGE}
EOF
)"
fi

SUMMARY="$(cat <<EOF
        ✅ **Backup completed successfully!**
        --------------------------------------------------
        **Git Metadata**
        Repository: ${REPOSITORY}
        - Owner: ${REPOSITORY_OWNER} [${OWNER_TYPE}]
        - Event: ${EVENT_NAME}
        - Ref:   ${REF}
        - Actor: ${ACTOR}

        ${UPLOAD_METADATA}
        --------------------------------------------------
        **API Response**
        - File version id: ${RECORD_ID}
        - You can access the shielded file from this link : https://dev.management.file-security.icredible.com/dashboard/file-management/${ENDPOINT_ID}/${DIR_RECORD_ID}
EOF
)"

# GitHub Actions command escaping
MESSAGE="${SUMMARY//'%'/'%25'}"
MESSAGE="${MESSAGE//$'\n'/'%0A'}"
MESSAGE="${MESSAGE//$'\r'/'%0D'}"

echo "::notice::$MESSAGE"
