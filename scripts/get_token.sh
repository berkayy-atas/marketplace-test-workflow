#!/bin/bash
set -e

echo "Requesting activation token..."
# Safely build JSON payload using jq
JSON_PAYLOAD=$(jq -n \
  --arg ac "$INPUT_ACTIVATION_CODE" \
  --arg uid "$GITHUB_REPOSITORY_ID" \
  --arg ip "$RUNNER_IP" \
  --arg os "Linux" \
  --arg et "Workstation" \
  --arg en "Github Endpoint ($GITHUB_REPOSITORY)" \
  '{activationCode: $ac, uniqueId: $uid, ip: $ip, operatingSystem: $os, endpointType: $et, endpointName: $en}')

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://dev.api.file-security.icredible.com/endpoint/activation" \
-H "Content-Type: application/json" \
-d "$JSON_PAYLOAD")

HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
JSON_BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_STATUS" -ne 200 ]; then
  echo "::error ::Activation failed: $JSON_BODY"
  exit 1
fi

# Set environment variables for subsequent steps
echo "endpointId=$(echo "$JSON_BODY" | jq -r '.data.endpointId')" >> $GITHUB_ENV
echo "TOKEN=$(echo "$JSON_BODY" | jq -r '.data.token')" >> $GITHUB_ENV

echo "Activation successful."
