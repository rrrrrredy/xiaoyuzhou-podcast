# xiaoyuzhou-podcast 踩坑详解

> 本文档是 SKILL.md Gotchas 章节的扩展版本，记录完整的调试过程和背景原因。
> 更新日期：2026-04-08

---

## 坑 1：小宇宙是 Next.js SPA，直接抓取无效

**现象**：
- `web_fetch("https://www.xiaoyuzhoufm.com/podcast/xxx")` → 返回空内容或 JS bundle
- `jina.ai/r/` 读取 → 同样无法获取实际节目内容
- `yt-dlp "https://www.xiaoyuzhoufm.com/episode/xxx"` → `ERROR: Unsupported URL` 或 404

**根本原因**：
小宇宙前端使用 Next.js，页面内容通过 JavaScript 动态渲染。所有静态爬取工具在拿到页面时只看到 JS bundle，而非实际内容。yt-dlp 不支持小宇宙的音频格式/URL 结构。

**正确路径**：
通过 iTunes Search API 获取 RSS Feed URL，再解析 RSS XML。RSS 是标准格式，包含所有剧集信息和直链音频 URL。

---

## 坑 2：RSS Feed 直连被封

**现象**：
```bash
# Direct connection
curl "https://feeds.simplecast.com/xxxxx" 
# → Connection timeout / Connection refused / 返回空
```

**根本原因**：
Some IPs are blocked by RSS Feed 服务商（Simplecast、Anchor 等）列入黑名单或地区限制。

**正确做法**：
```bash
# 必须走上游代理
curl ${HTTP_PROXY:+-x $HTTP_PROXY} -L "https://feeds.simplecast.com/xxxxx" -o /tmp/podcast_feed.xml
```

**注意事项**：
- 必须加 `-L` 参数跟随重定向（很多 RSS URL 有 302 跳转）
- Set HTTP_PROXY to a proxy that can access external services

---

## 坑 3：iTunes Search API 直连正常

**背景**：
容易误以为访问 Apple 服务也需要代理，实际上 iTunes Search API（api.apple.com/search 端点）works fine with direct connection。

**验证**：
```bash
curl "https://itunes.apple.com/search?term=忽左忽右&media=podcast&country=CN&limit=5"
# → 正常返回 JSON，包含 feedUrl 字段
```

**搜索技巧**：
- `country=CN`：优先返回中文播客
- 如搜索结果为空，尝试英文名（如 `Leftward`）
- `limit=5` 足够，iTunes 会排最相关的在前

---

## 坑 4：`infsh`（inference.sh CLI）安装失败

**现象**：
```bash
curl -fsSL https://get.inference.sh | sh
# → 403 Forbidden
```

**根本原因**：
`infsh` is a CLI tool that depends on the external inference.sh service, which may be offline or return 403.

**解决方案**：
改用 `faster-whisper`，完全本地 Python 包，无需外部服务：
```bash
pip install faster-whisper
```

---

## 坑 5：faster-whisper 转写耗时预估

**实测数据**（small 模型，CPU，int8 量化）：

| 音频时长 | 实测耗时（CPU） | 备注 |
|----------|--------------|------|
| 30 分钟  | ~8-12 分钟   | 取决于 CPU 性能 |
| 60 分钟  | ~15-25 分钟  | |
| 80 分钟  | ~20-30 分钟  | 忽左忽右标准时长 |
| 120 分钟 | ~30-45 分钟  | 建议用 medium 换质量 |

**加速技巧**：
- `vad_filter=True`：启用语音活动检测，跳过静音段，可减少 10-20% 耗时
- `compute_type="int8"`：整数量化，速度比 float32 快约 2 倍
- 不要用 `large-v3` 做批量任务，CPU 上极慢

---

## 坑 6：小宇宙内部节目 ID 不可靠

**背景**：
曾尝试直接构造 `https://www.xiaoyuzhoufm.com/podcasts/5e4ee557418a84a046263c3a` 来访问忽左忽右，但：
1. 这个 ID 可能是旧版或错误 ID
2. 即使 ID 正确，SPA 页面也无法爬取（参见坑 1）

**正确姿势**：
始终通过 iTunes API 搜索 → 获取 feedUrl → 解析 RSS，不要假设节目 ID。

---

## 坑 7：yt-dlp 不可用

**尝试过的命令**：
```bash
yt-dlp "https://www.xiaoyuzhoufm.com/episode/xxxxxxxx"
# → ERROR: Unsupported URL: https://www.xiaoyuzhoufm.com/episode/...
```

**结论**：yt-dlp 不支持小宇宙 URL，彻底放弃此路径。

---

## 坑 8：RSS `<enclosure>` 音频 URL 需要跟随重定向

**现象**：
直接 `curl "<enclosure url>"` 下载得到一个很小的 HTML 文件（302 页面），不是音频。

**原因**：
很多播客托管服务（Simplecast、Buzzsprout 等）的音频 URL 有重定向统计跳转。

**修复**：
始终加 `-L` 参数：
```bash
curl ${HTTP_PROXY:+-x $HTTP_PROXY} -L "${AUDIO_URL}" -o /tmp/podcast_episode.m4a
```

---

## 调试工具清单

```bash
# 检查 RSS XML 是否下载正常（看头部几行）
head -50 /tmp/podcast_feed.xml

# 检查 RSS 中有多少剧集
grep -c '<item>' /tmp/podcast_feed.xml

# 检查音频文件是否完整（非 HTML 302 页面）
file /tmp/podcast_episode.m4a
# 正常输出：MPEG ADTS, AAC, ... 或 ISO Media, MP4 ...
# 异常输出：HTML document, ASCII text

# 检查音频时长（需要 ffprobe）
ffprobe -i /tmp/podcast_episode.m4a -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null
```

---

## 已知限制

1. **会员专属剧集**：RSS Feed 通常不包含付费/会员剧集的音频 URL，无法下载
2. **仅支持最新一期**：`fetch_episode.sh` 默认只取 `items[0]`，如需历史剧集需修改脚本
3. **音频格式**：大多数是 `.m4a`，少数可能是 `.mp3`，`faster-whisper` 两者都支持
4. **中英混合播客**：`language="zh"` 对英文段落准确率下降，可改为 `language=None` 让模型自动检测
