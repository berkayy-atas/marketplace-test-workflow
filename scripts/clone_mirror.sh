#!/bin/bash
set -e

echo "Cloning repository in mirror mode..."
git clone --mirror . repo-mirror
echo "Clone complete."
