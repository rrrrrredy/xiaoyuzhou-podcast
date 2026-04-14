---
name: xiaoyuzhou-podcast
description: 获取小宇宙（xiaoyuzhoufm.com）播客节目内容：查找最新一期、下载音频、本地转写（faster-whisper）、生成结构化总结。触发词：小宇宙、小宇宙播客、忽左忽右、播客转写、播客总结、获取播客内容、下载播客。不适用：非小宇宙平台（Spotify/Apple Podcasts 等）；需要实时内容（转写需 15-30 分钟）。
tags: [podcast, xiaoyuzhou, transcription, audio, whisper]
---

# xiaoyuzhou-podcast V1

> 小宇宙播客内容获取、转写与总结工具。  
> 核心路径：iTunes API → RSS Feed → 音频下载 → faster-whisper 本地转写 → LLM 结构化总结

---

## Hard Stop

```
规则：同一步骤失败超过 3 次，立即停止，不再重试。
输出：列出所有失败方案及原因，标记"需要人工介入"，等待人工确认。
特别注意：小宇宙 SPA 限制导致多种常见方案不可用（见 Gotchas），
          遇到 404/超时/空结果，优先怀疑是否走了错误路径，而不是重试。
```

---

## Gotchas ⚠️

| # | 踩坑 | 正确做法 |
|---|------|---------|
| 1 | 小宇宙是 Next.js SPA，页面内容动态渲染 | `web_fetch` / Jina Reader / `yt-dlp` 全部失败。**唯一可靠路径：RSS Feed** |
| 2 | RSS Feed URL 直连被封 | Set `HTTP_PROXY` env var; some networks block RSS feeds directly |
| 3 | iTunes Search API 不需要代理 | 直连即可，是获取 feedUrl 的唯一可靠入口 |
| 4 | `infsh` CLI 安装返回 403 | 改用 `pip install faster-whisper`，完全本地 CPU 转写 |
| 5 | 转写耗时超长 | small 模型转写 80 分钟音频约需 **15-30 分钟** CPU 时间，提前告知用户 |
| 6 | 小宇宙节目 ID 不可靠 | 不要直接构造 `xiaoyuzhoufm.com/podcasts/<id>` URL 去抓取，通过 iTunes API → feedUrl 是唯一可信路径 |
| 7 | yt-dlp 对小宇宙 URL 返回 404 | SPA 限制，不可用，勿尝试 |
| 8 | RSS 中 `<enclosure>` 音频 URL 需要跟随重定向 | `curl` 加 `-L` 参数，否则下载得到 302 页面 |

---

## 使用流程（Happy Path）

### 前置条件

- A working HTTP proxy (set `HTTP_PROXY` env var) if RSS feeds are blocked
- `curl`、`python3` 已安装
- `faster-whisper` 已安装（首次运行 Step 5 时自动 pip install）
- 磁盘空间：音频文件约 50-200MB

---

### Step 1：查找播客 RSS URL（iTunes Search API，无需代理）

```bash
PODCAST_NAME="忽左忽右"  # 替换为目标播客名

curl "https://itunes.apple.com/search?term=${PODCAST_NAME}&media=podcast&country=CN&limit=5" \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data['results']:
    print(r['collectionName'], '->', r.get('feedUrl', 'N/A'))
"
```

**输出示例**：
```
忽左忽右 -> https://feeds.simplecast.com/xxxxxxxx
```

> ℹ️ iTunes 直连，无需代理。如搜索无结果，尝试英文名或缩写。

---

### Step 2：下载 RSS XML（必须走上游代理）

```bash
FEED_URL="https://feeds.simplecast.com/xxxxxxxx"  # 替换为上一步获取的 feedUrl

curl ${HTTP_PROXY:+-x $HTTP_PROXY} -L "${FEED_URL}" -o /tmp/podcast_feed.xml
echo "RSS 下载完成，大小: $(wc -c < /tmp/podcast_feed.xml) bytes"
```

---

### Step 3：解析最新一期

```python
# 运行：python3 /path/to/parse_latest.py
import xml.etree.ElementTree as ET

tree = ET.parse("/tmp/podcast_feed.xml")
root = tree.getroot()
ns = {'itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd'}

channel = root.find('channel')
items = channel.findall('item')
latest = items[0]

title    = latest.find('title').text
enclosure = latest.find('enclosure')
audio_url = enclosure.get('url')
duration  = latest.find('itunes:duration', ns)
duration  = duration.text if duration is not None else "Unknown"

print(f"标题: {title}")
print(f"时长: {duration}")
print(f"音频URL: {audio_url}")
```

> 或直接使用 `scripts/fetch_episode.sh` 一键完成 Step 1-4。

---

### Step 4：下载音频（必须走上游代理）

```bash
AUDIO_URL="<上一步输出的音频URL>"

curl ${HTTP_PROXY:+-x $HTTP_PROXY} -L "${AUDIO_URL}" \
     -o /tmp/podcast_episode.m4a \
     --progress-bar
echo "音频下载完成"
```

> ⚠️ 文件体积约 50-200MB，请确认磁盘空间足够。

---

### Step 5：本地转写（faster-whisper）

```bash
python3 scripts/transcribe.py \
    /tmp/podcast_episode.m4a \
    /tmp/podcast_transcript.txt
```

或直接内联执行：

```python
# pip install faster-whisper -q（首次运行）
from faster_whisper import WhisperModel

model = WhisperModel("small", device="cpu", compute_type="int8")
segments, info = model.transcribe(
    "/tmp/podcast_episode.m4a",
    language="zh",
    beam_size=5
)

with open("/tmp/podcast_transcript.txt", "w", encoding="utf-8") as f:
    for seg in segments:
        line = f"[{seg.start:.1f}s-{seg.end:.1f}s] {seg.text}\n"
        f.write(line)
        print(line, end="", flush=True)

print("\n✅ 转写完成 →", "/tmp/podcast_transcript.txt")
```

> ⚠️ **耗时警告**：small 模型转写 80 分钟音频约需 15-30 分钟 CPU 时间。  
> 转写质量不足时换 `medium` 模型（耗时加倍）。

---

### Step 6：生成结构化总结（LLM）

转写完成后，读取 `/tmp/podcast_transcript.txt`，发给 LLM 生成总结。

**推荐 Prompt**：

```
以下是播客「{PODCAST_NAME}」的转写文本（带时间戳），请生成结构化总结：

{transcript}

输出格式：
1. 本期主题（1-2句话）
2. 主要观点（带时间戳的 bullet points，每条 ≤50字）
3. 关键词（5-10个）
4. 亮点金句（2-3条，带时间戳）
```

---

## 快速入口（一键脚本）

```bash
# 一键获取并下载最新一期（Step 1-4）
bash scripts/fetch_episode.sh "忽左忽右"

# 转写（Step 5）
python3 scripts/transcribe.py \
    /tmp/podcast_episode.m4a /tmp/podcast_transcript.txt
```

---

## 文件说明

| 路径 | 说明 |
|------|------|
| `scripts/fetch_episode.sh` | Step 1-4 一键脚本：搜索 → 下载 RSS → 解析 → 下载音频 |
| `scripts/transcribe.py` | Step 5：faster-whisper 本地转写 |
| `references/troubleshooting.md` | 完整踩坑详解与调试指南 |

---

## Changelog

| 版本 | 日期 | 说明 |
|------|------|------|
| V1 | 2026-04-08 | 初版：iTunes → RSS → faster-whisper 完整链路 |
