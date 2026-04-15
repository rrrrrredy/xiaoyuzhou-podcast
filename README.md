# xiaoyuzhou-podcast

Xiaoyuzhou (小宇宙) podcast content fetcher, transcriber & summarizer.

> OpenClaw Skill — works with [OpenClaw](https://github.com/openclaw/openclaw) AI agents

## What It Does

Fetches podcast episodes from Xiaoyuzhou (xiaoyuzhoufm.com) via the iTunes API → RSS feed pipeline, downloads audio, transcribes locally using faster-whisper, and generates structured summaries with key topics, quotes, and timestamps. No browser scraping needed — bypasses the SPA entirely through RSS.

## Quick Start

```bash
openclaw skill install xiaoyuzhou-podcast
# Or:
git clone https://github.com/rrrrrredy/xiaoyuzhou-podcast.git ~/.openclaw/skills/xiaoyuzhou-podcast
```

One-command fetch + download:
```bash
bash scripts/fetch_episode.sh "忽左忽右"
```

Then transcribe:
```bash
python3 scripts/transcribe.py /tmp/podcast_episode.m4a /tmp/podcast_transcript.txt
```

## Features

- **RSS-based pipeline**: iTunes Search API → RSS feed → audio download (bypasses SPA)
- **Local transcription**: faster-whisper with timestamps, no external API needed
- **Structured summaries**: topics, key points, keywords, highlight quotes with timestamps
- **One-click scripts**: `fetch_episode.sh` handles search → download in one command
- **Proxy-aware**: auto-routes RSS and audio downloads through upstream proxy
- **Hard stop protection**: auto-stops after 3 failures per step

## Usage

Trigger with natural language:

- "下载忽左忽右最新一期"
- "小宇宙播客转写"
- "播客总结" / "获取播客内容"
- "转写这期播客"

**Full pipeline**:
1. Search podcast → get RSS URL (iTunes API, no proxy needed)
2. Download RSS XML (requires proxy)
3. Parse latest episode metadata
4. Download audio file (requires proxy, ~50-200MB)
5. Transcribe with faster-whisper (~15-30 min for 80 min audio)
6. Generate structured summary via LLM

## Project Structure

```
xiaoyuzhou-podcast/
├── SKILL.md                      # Skill definition and full workflow
├── scripts/
│   ├── fetch_episode.sh          # One-click: search → download audio
│   ├── setup.sh                  # Dependency setup
│   └── transcribe.py             # Local faster-whisper transcription
├── references/
│   └── troubleshooting.md        # Debugging guide and known issues
├── README.md
├── LICENSE
└── .gitignore
```

## Requirements

- OpenClaw agent runtime
- Python 3 with `faster-whisper` (`pip install faster-whisper`)
- `curl` for audio/RSS downloads
- Upstream proxy for RSS feed and audio access
- ~200MB+ disk space for audio files

## License

[MIT](LICENSE)
