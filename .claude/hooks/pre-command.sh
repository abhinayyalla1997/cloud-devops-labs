#!/bin/bash

COMMAND="$1"

# 🚫 Block git push
if [[ "$COMMAND" == *"git push"* ]]; then
  echo "❌ ERROR: git push is blocked. Please push manually after review."
  exit 1
fi

# 🚫 Block file deletion (rm)
if [[ "$COMMAND" == *"rm "* ]]; then
  echo "❌ ERROR: File deletion is blocked. Please confirm manually."
  exit 1
fi

# 🚫 Block force delete
if [[ "$COMMAND" == *"rm -rf"* ]]; then
  echo "❌ ERROR: Dangerous deletion blocked."
  exit 1
fi

echo "✅ Command allowed"
