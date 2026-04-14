# xiaoyuzhou-podcast

Fetch, download, and transcribe podcast episodes from Xiaoyuzhou (小宇宙) using iTunes API + RSS Feed + faster-whisper.

An [OpenClaw](https://github.com/openclaw/openclaw) Skill for downloading and transcribing Chinese podcast content.

## Installation

### Option A: OpenClaw (recommended)
```bash
# Clone to OpenClaw skills directory
git clone https://github.com/rrrrrredy/xiaoyuzhou-podcast ~/.openclaw/skills/xiaoyuzhou-podcast

# Run setup (installs Python dependencies)
bash ~/.openclaw/skills/xiaoyuzhou-podcast/scripts/setup.sh
```

### Option B: Standalone
```bash
git clone https://github.com/rrrrrredy/xiaoyuzhou-podcast
cd xiaoyuzhou-podcast
bash scripts/setup.sh
```

## Dependencies

### System
- `curl` (built-in)
- `ffmpeg` (`apt install ffmpeg`)
- Python 3

### Python packages
- `faster-whisper` — local CPU speech-to-text (Whisper model)

### Other Skills (optional)
None

## Usage

### Fetch latest episode (search → download RSS → parse → download audio)
```bash
bash scripts/fetch_episode.sh "忽左忽右"
```

### Transcribe downloaded audio
```bash
python3 scripts/transcribe.py \
  /tmp/podcast_episode.m4a \
  /tmp/podcast_transcript.txt
```

### Full pipeline
```bash
# Step 1-4: Find and download
bash scripts/fetch_episode.sh "播客名称"

# Step 5: Transcribe
python3 scripts/transcribe.py \
  /tmp/podcast_episode.m4a /tmp/podcast_transcript.txt

# Step 6: Feed transcript to LLM for structured summary
```

### Proxy support
RSS feeds and audio downloads may require a proxy on some networks:
```bash
export HTTP_PROXY="http://your-proxy:port"
bash scripts/fetch_episode.sh "忽左忽右"
```

## How It Works

1. **iTunes Search API** — Finds the podcast's RSS feed URL (direct connection, no proxy needed)
2. **RSS Download** — Fetches the RSS XML (may need proxy)
3. **Parse Latest Episode** — Extracts title, duration, and audio URL from RSS
4. **Download Audio** — Downloads the `.m4a` audio file (may need proxy, follows redirects)
5. **Transcribe** — Uses `faster-whisper` (small model, CPU int8) for speech-to-text
6. **Summarize** — Feed transcript to any LLM for structured summary

## Key Gotchas

- **Xiaoyuzhou is a Next.js SPA** — `web_fetch`, Jina Reader, and `yt-dlp` all fail. RSS is the only reliable path.
- **RSS feeds may be blocked** on some networks — use `HTTP_PROXY`
- **Audio URLs require redirect following** — always use `curl -L`
- **Transcription takes 15-30 minutes** for an 80-minute episode (small model, CPU)

## Project Structure

```
xiaoyuzhou-podcast/
├── SKILL.md              # Main skill definition
├── scripts/
│   ├── setup.sh          # Dependency installation
│   ├── fetch_episode.sh  # One-click fetch script (Steps 1-4)
│   └── transcribe.py     # faster-whisper transcription (Step 5)
├── references/
│   └── troubleshooting.md  # Detailed troubleshooting guide
└── README.md
```

## License

MIT
