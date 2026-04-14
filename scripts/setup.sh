#!/usr/bin/env bash
# setup.sh - Install dependencies for xiaoyuzhou-podcast
# Usage: bash scripts/setup.sh

set -e

echo "🔍 Checking xiaoyuzhou-podcast dependencies..."

MISSING=0

# Check ffmpeg (for audio probing)
if command -v ffmpeg &>/dev/null; then
  echo "✅ ffmpeg $(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')"
else
  echo "⚠️  ffmpeg not installed"
  MISSING=1
  echo "📦 Installing ffmpeg..."
  apt update -qq && apt install -y ffmpeg
  echo "✅ ffmpeg installed"
fi

# Check Python3
if ! command -v python3 &>/dev/null; then
  echo "❌ python3 not found"
  exit 1
fi
echo "✅ python3 $(python3 --version 2>&1 | awk '{print $2}')"

# Check faster-whisper
if python3 -c "import faster_whisper" &>/dev/null; then
  echo "✅ faster-whisper"
else
  echo "⚠️  faster-whisper not installed"
  MISSING=1
fi

if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "📦 Installing missing Python dependencies (faster-whisper is large, please wait)..."
  pip install faster-whisper
fi

# Final check
echo ""
echo "🔍 Final verification..."
ffmpeg -version >/dev/null 2>&1 && echo "✅ ffmpeg" || echo "❌ ffmpeg verification failed"
python3 -c "import faster_whisper; print('✅ faster-whisper')"
curl --version >/dev/null 2>&1 && echo "✅ curl" || echo "❌ curl not found"

echo "🎉 Setup complete! xiaoyuzhou-podcast is ready to use."
