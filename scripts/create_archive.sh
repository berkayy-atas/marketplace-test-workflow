#!/bin/bash
set -e

echo "Creating and encrypting archive..."
# GitHub context variables are available as environment variables
REPO_NAME=$(basename "${GITHUB_REPOSITORY}")
ENC_FILE_NAME="$REPO_NAME.tar.zst.enc"

tar -cf repo.tar repo-mirror
zstd -9 repo.tar -o repo.tar.zst
openssl enc -aes-256-cbc -salt -pbkdf2 -in repo.tar.zst -out "$ENC_FILE_NAME" -pass pass:$INPUT_ENCRYPTION_PASSWORD

# Set environment variables for subsequent steps
echo "ENC_FILE_NAME=$ENC_FILE_NAME" >> $GITHUB_ENV
echo "UNCOMPRESSED_SIZE=$(stat --printf='%s' repo.tar)" >> $GITHUB_ENV
echo "COMPRESSED_SIZE=$(stat --printf='%s' $ENC_FILE_NAME)" >> $GITHUB_ENV

echo "::notice ::Archive '$ENC_FILE_NAME' created successfully."
