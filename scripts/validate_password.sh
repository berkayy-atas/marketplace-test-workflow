#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "Validating encryption password length..."
if [ "${#INPUT_ENCRYPTION_PASSWORD}" -lt 32 ]; then
  echo "::error ::The encryption_password must be at least 32 characters long (got ${#INPUT_ENCRYPTION_PASSWORD})."
  exit 1
fi
echo "Password length is valid."
