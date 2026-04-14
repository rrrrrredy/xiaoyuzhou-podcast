#!/usr/bin/env python3
"""
transcribe.py — Step 5: 使用 faster-whisper 本地 CPU 转写播客音频

用法:
    python3 transcribe.py <音频文件路径> [转写输出路径]

示例:
    python3 transcribe.py /tmp/podcast_episode.m4a /tmp/podcast_transcript.txt

参数:
    audio_path      输入音频文件（支持 .m4a / .mp3 / .wav 等）
    output_path     输出文本路径（默认：/tmp/podcast_transcript.txt）

模型选择:
    --model small   快速，质量中等（默认，推荐首选）
    --model medium  质量较好，耗时约 2 倍
    --model large   最高质量，耗时约 4-5 倍

⚠️  耗时警告: small 模型转写 80 分钟音频约需 15-30 分钟 CPU 时间
"""

import sys
import os
import time
import argparse

def install_faster_whisper():
    """首次运行时自动安装 faster-whisper"""
    try:
        import faster_whisper  # noqa
    except ImportError:
        print("📦 首次运行，安装 faster-whisper...")
        import subprocess
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "faster-whisper", "-q"],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f"❌ 安装失败:\n{result.stderr}")
            sys.exit(1)
        print("✅ faster-whisper 安装完成")


def transcribe(audio_path: str, output_path: str, model_size: str = "small"):
    """执行转写"""
    from faster_whisper import WhisperModel

    if not os.path.exists(audio_path):
        print(f"❌ 音频文件不存在: {audio_path}")
        sys.exit(1)

    file_size_mb = os.path.getsize(audio_path) / (1024 * 1024)
    print(f"🎵 音频文件: {audio_path} ({file_size_mb:.1f} MB)")
    print(f"🤖 模型: {model_size} | 设备: CPU (int8)")
    print(f"⚠️  预计耗时: {int(file_size_mb * 0.15)}-{int(file_size_mb * 0.3)} 分钟（rough estimate）")
    print("🚀 开始转写...\n")

    start_time = time.time()

    model = WhisperModel(model_size, device="cpu", compute_type="int8")
    segments, info = model.transcribe(
        audio_path,
        language="zh",
        beam_size=5,
        vad_filter=True,          # 过滤静音段，加快速度
        vad_parameters={"min_silence_duration_ms": 500},
    )

    print(f"检测到语言: {info.language}（置信度 {info.language_probability:.2%}）\n")
    print("=" * 60)

    lines = []
    segment_count = 0

    for seg in segments:
        line = f"[{seg.start:.1f}s-{seg.end:.1f}s] {seg.text.strip()}"
        lines.append(line)
        print(line, flush=True)
        segment_count += 1

    elapsed = time.time() - start_time
    print("\n" + "=" * 60)
    print(f"✅ 转写完成！共 {segment_count} 段，耗时 {elapsed/60:.1f} 分钟")

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"📄 转写文本已保存到: {output_path}")
    print(f"\n下一步: 将转写文本发给 LLM 生成结构化总结（参见 SKILL.md Step 6）")


def main():
    parser = argparse.ArgumentParser(
        description="faster-whisper 本地 CPU 转写播客音频",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument("audio_path", help="输入音频文件路径")
    parser.add_argument("output_path", nargs="?",
                        default="/tmp/podcast_transcript.txt",
                        help="输出文本路径（默认 /tmp/podcast_transcript.txt）")
    parser.add_argument("--model", default="small",
                        choices=["tiny", "base", "small", "medium", "large-v2", "large-v3"],
                        help="Whisper 模型大小（默认 small）")

    args = parser.parse_args()

    install_faster_whisper()
    transcribe(args.audio_path, args.output_path, args.model)


if __name__ == "__main__":
    main()
