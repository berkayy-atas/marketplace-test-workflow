#!/bin/bash

set -e

REPO_NAME=$(basename "${{ github.repository }}")
ENC_FILE_NAME="$REPO_NAME.tar.zst.enc"

tar -cf repo.tar repo-mirror
zstd -9 repo.tar -o repo.tar.zst
openssl enc -aes-256-cbc -salt -pbkdf2 -in repo.tar.zst -out "$ENC_FILE_NAME" -pass pass:${{ inputs.encryption_password }}

echo "ENC_FILE_NAME=$ENC_FILE_NAME" >> $GITHUB_ENV
echo "UNCOMPRESSED_SIZE=$(stat --printf='%s' repo.tar)" >> $GITHUB_ENV
echo "COMPRESSED_SIZE=$(stat --printf='%s' repo.tar.zst.enc)" >> $GITHUB_ENV

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://dev.api.file-security.icredible.com/endpoint/activation" \
-H "Content-Type: application/json" \
-d "{
  \"activationCode\": \"$ACTIVATION_CODE\",
  \"uniqueId\": \"$GITHUB_REPOSITORY_ID\",
  \"ip\": \"$RUNNER_IP\",
  \"operatingSystem\": \"Linux\",
  \"endpointType\": \"Workstation\",
  \"endpointName\": \"Github Endpoint ($GITHUB_REPOSITORY)\"
}")

HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
JSON_BODY=$(echo "$RESPONSE" | head -n -1)
if [ "$HTTP_STATUS" -ne 200 ]; then
  echo "Activation failed: $JSON_BODY"
  exit 1
fi

echo "endpointId=$(echo "$JSON_BODY" | jq -r '.data.endpointId')" >> $GITHUB_ENV
echo "TOKEN=$(echo "$JSON_BODY" | jq -r '.data.token')" >> $GITHUB_ENV

EVENT="${{ github.event_name }}"
REF="${{ github.ref }}"
ACTOR="${{ github.actor }}"
OWNER="${{ github.repository_owner }}"
OWNER_TYPE="${{ github.event.repository.owner.type }}"

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  COMMIT=$(git log -1 --pretty=format:"%H")
  SHORT=$(git log -1 --pretty=format:"%h")
  PARENTS=$(git log -1 --pretty=format:"%P")
  AUTHOR=$(git log -1 --pretty=format:"%an <%ae>")
  DATE=$(git log -1 --pretty=format:"%ad")
  COMMITTER=$(git log -1 --pretty=format:"%cn")
  MESSAGE=$(git log -1 --pretty=format:"%s%n%b")
else
  COMMIT=""
  SHORT=""
  PARENTS=""
  AUTHOR=""
  DATE=""
  COMMITTER=""
  MESSAGE=""
fi

CURL_ARGS=(
  -F "MetaData[Event]=$EVENT"
  -F "MetaData[Ref]=$REF"
  -F "MetaData[Actor]=$ACTOR"
  -F "MetaData[Owner]=$OWNER"
  -F "MetaData[OwnerType]=$OWNER_TYPE"
)
[ -n "$COMMIT" ] && CURL_ARGS+=(-F "MetaData[Commit]=$COMMIT")
[ -n "$SHORT" ] && CURL_ARGS+=(-F "MetaData[CommitShort]=$SHORT")
[ -n "$PARENTS" ] && CURL_ARGS+=(-F "MetaData[Parents]=$PARENTS")
[ -n "$AUTHOR" ] && CURL_ARGS+=(-F "MetaData[Author]=$AUTHOR")
[ -n "$DATE" ] && CURL_ARGS+=(-F "MetaData[Date]=$DATE")
[ -n "$COMMITTER" ] && CURL_ARGS+=(-F "MetaData[Committer]=$COMMITTER")
[ -n "$MESSAGE" ] && CURL_ARGS+=(-F "MetaData[Message]=$MESSAGE")

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "https://dev.api.file-security.icredible.com/backup/shield" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@$ENC_FILE_NAME" \
  -F "Size=$UNCOMPRESSED_SIZE" \
  -F "CompressedFileSize=$COMPRESSED_SIZE" \
  -F "Attributes=32" \
  -F "FileName=$GITHUB_REPOSITORY" \
  -F "CompressionEngine=None" \
  -F "CompressionLevel=NoCompression" \
  -F "FullPath=/$GITHUB_REPOSITORY/repo.tar.zst" \
  -F "encryptionType=None" \
  -F "RevisionType=1" \
  "${CURL_ARGS[@]}"
)

HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
JSON_BODY=$(echo "$RESPONSE" | head -n -1)
if [ "$HTTP_STATUS" -ne 200 ]; then
  echo "Upload failed: $JSON_BODY"
  exit 1
fi

echo "recordId=$(echo "$JSON_BODY" | jq -r '.data.recordId')" >> $GITHUB_ENV
echo "directoryRecordId=$(echo "$JSON_BODY" | jq -r '.data.directoryRecordId')" >> $GITHUB_ENV

echo "commit=$COMMIT" >> $GITHUB_ENV
echo "commitShort=$SHORT" >> $GITHUB_ENV
echo "parents=$PARENTS" >> $GITHUB_ENV
echo "author=$AUTHOR" >> $GITHUB_ENV
echo "date=$DATE" >> $GITHUB_ENV
echo "committer=$COMMITTER" >> $GITHUB_ENV
echo "message=$(git log -1 --pretty=format:"%s%n%b" | tr '\n' ' ')" >> $GITHUB_ENV

echo "Backup uploaded successfully."

UPLOAD_METADATA=""
if [ -n "${{ env.commit }}" ]; then
  UPLOAD_METADATA=$(cat <<EOF
--------------------------------------------------
**Upload Metadata**
- Commit:      ${{ env.commit }}
- CommitShort: ${{ env.commitShort }}
- Parents:     ${{ env.parents }}
- Author:      ${{ env.author }}
- Date:        ${{ env.date }}
- Committer:   ${{ env.committer }}
- Message:     $(git log -1 --pretty=format:"%s%n%b" | tr '\n' ' ')
EOF
)
fi

SUMMARY=$(cat <<EOF
✅ **Backup completed successfully!**
--------------------------------------------------
**Git Metadata**
Repository: ${{ github.repository }}
- Owner: ${{ github.repository_owner }} [${{ github.event.repository.owner.type }}]
- Event: ${{ github.event_name }}
- Ref:   ${{ github.ref }}
- Actor: ${{ github.actor }}

${UPLOAD_METADATA}
--------------------------------------------------
**API Response**
- File version id: ${{ env.recordId }}
- You can access the shielded file from this link : https://dev.management.file-security.icredible.com/dashboard/file-management/$ENDPOINT_ID/$DIRECTORY_RECORD_ID
EOF
)

MESSAGE="${SUMMARY//'%'/'%25'}"
MESSAGE="${MESSAGE//$'\n'/'%0A'}"
MESSAGE="${MESSAGE//$'\r'/'%0D'}"

echo "::notice::$MESSAGE"