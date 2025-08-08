#!/bin/bash
set -e

echo "Installing dependencies: zstd and jq..."
sudo apt-get update
sudo apt-get install -y zstd jq
echo "Dependencies installed."
