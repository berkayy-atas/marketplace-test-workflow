#!/bin/bash
set -e

echo "Generating backup summary..."
UPLOAD_METADATA=""
if [ -n "$commit" ]; then
  UPLOAD_METADATA=$(cat <<EOF
--------------------------------------------------
**Upload Metadata**
- Commit:      $commit
- CommitShort: $commitShort
- Parents:     $parents
- Author:      $author
- Date:        $date
- Committer:   $committer
- Message:     $message
EOF
)
fi

SUMMARY=$(cat <<EOF
✅ **Backup completed successfully!**
--------------------------------------------------
**Git Metadata**
Repository: $GITHUB_REPOSITORY
- Owner: $GITHUB_REPOSITORY_OWNER [$GITHUB_EVENT_REPOSITORY_OWNER_TYPE]
- Event: $GITHUB_EVENT_NAME
- Ref:   $GITHUB_REF
- Actor: $GITHUB_ACTOR

$UPLOAD_METADATA
--------------------------------------------------
**API Response**
- File version id: $recordId
- You can access the shielded file from this link : https://dev.management.file-security.icredible.com/dashboard/file-management/$endpointId/$directoryRecordId
EOF
)

# Escape special characters for the ::notice command
MESSAGE="${SUMMARY//'%'/'%25'}"
MESSAGE="${MESSAGE//$'\n'/'%0A'}"
MESSAGE="${MESSAGE//$'\r'/'%0D'}"

echo "::notice::$MESSAGE"
