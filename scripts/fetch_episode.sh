#!/usr/bin/env bash
# fetch_episode.sh — Step 1-4：查 RSS URL → 下载 XML → 解析最新一期 → 下载音频
# 用法：bash fetch_episode.sh "<播客名>"
# 示例：bash fetch_episode.sh "忽左忽右"
#
# 输出文件：
#   /tmp/podcast_feed.xml        RSS XML
#   /tmp/podcast_episode.m4a     最新一期音频
#   /tmp/podcast_episode_info.txt 标题/时长/音频URL

set -euo pipefail

PODCAST_NAME="${1:-}"
PROXY="${HTTP_PROXY:-}"
FEED_XML="/tmp/podcast_feed.xml"
AUDIO_OUT="/tmp/podcast_episode.m4a"
INFO_OUT="/tmp/podcast_episode_info.txt"

if [[ -z "${PODCAST_NAME}" ]]; then
    echo "用法：$0 <播客名>"
    echo "示例：$0 忽左忽右"
    exit 1
fi

echo "=== Step 1: iTunes Search API（直连，无需代理）==="
SEARCH_RESULT=$(curl -s "https://itunes.apple.com/search?term=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote('${PODCAST_NAME}'))")&media=podcast&country=CN&limit=5")

echo "搜索结果："
echo "${SEARCH_RESULT}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('未找到结果，请尝试英文名或缩写')
    exit(1)
for i, r in enumerate(results):
    print(f\"  [{i}] {r['collectionName']} -> {r.get('feedUrl', 'N/A')}\")
"

FEED_URL=$(echo "${SEARCH_RESULT}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('')
    exit(0)
# 取第一个有 feedUrl 的结果
for r in results:
    url = r.get('feedUrl', '')
    if url:
        print(url)
        break
")

if [[ -z "${FEED_URL}" ]]; then
    echo "❌ 未找到播客「${PODCAST_NAME}」的 RSS Feed URL，请检查名称是否正确。"
    exit 1
fi

echo ""
echo "✅ 找到 RSS Feed: ${FEED_URL}"

echo ""
echo "=== Step 2: 下载 RSS XML（走上游代理）==="
curl ${PROXY:+-x "${PROXY}"} -L "${FEED_URL}" -o "${FEED_XML}" --silent --show-error
echo "✅ RSS 下载完成，大小: $(wc -c < "${FEED_XML}") bytes"

echo ""
echo "=== Step 3: 解析最新一期 ==="
python3 - <<'PYEOF'
import xml.etree.ElementTree as ET, sys

FEED_XML = "/tmp/podcast_feed.xml"
INFO_OUT  = "/tmp/podcast_episode_info.txt"

tree = ET.parse(FEED_XML)
root = tree.getroot()
ns = {'itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd'}

channel = root.find('channel')
items   = channel.findall('item')

if not items:
    print("❌ RSS 中没有找到任何剧集，请检查 XML 内容")
    sys.exit(1)

latest    = items[0]
title     = latest.find('title').text or "Unknown"
enclosure = latest.find('enclosure')
audio_url = enclosure.get('url') if enclosure is not None else None
dur_el    = latest.find('itunes:duration', ns)
duration  = dur_el.text if dur_el is not None else "Unknown"
pub_date  = latest.findtext('pubDate', default='Unknown')

if not audio_url:
    print("❌ 最新一期没有 <enclosure> 音频 URL，可能是会员专属或 RSS 格式异常")
    sys.exit(1)

info = f"""标题: {title}
发布时间: {pub_date}
时长: {duration}
音频URL: {audio_url}
"""
print(info)
with open(INFO_OUT, "w", encoding="utf-8") as f:
    f.write(info)
# 将 audio_url 单独写入供 Step 4 读取
with open("/tmp/_podcast_audio_url.txt", "w") as f:
    f.write(audio_url)
PYEOF

echo ""
echo "=== Step 4: 下载音频（走上游代理）==="
AUDIO_URL=$(cat /tmp/_podcast_audio_url.txt)
echo "音频 URL: ${AUDIO_URL}"
echo "⚠️  下载中，文件约 50-200MB，请稍候..."
curl ${PROXY:+-x "${PROXY}"} -L "${AUDIO_URL}" -o "${AUDIO_OUT}" --progress-bar

echo ""
echo "✅ 全部完成！"
echo "   RSS XML      : ${FEED_XML}"
echo "   音频文件     : ${AUDIO_OUT}"
echo "   剧集信息     : ${INFO_OUT}"
echo ""
echo "下一步: python3 scripts/transcribe.py ${AUDIO_OUT} /tmp/podcast_transcript.txt"
