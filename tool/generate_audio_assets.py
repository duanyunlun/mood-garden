#!/usr/bin/env python3
"""生成占位音效（PRD 7.2.2「配合动效与轻音效」）。

⚠️ 这是**用代码合成的占位音**，不是正式音效设计：
   没有采样素材，全部由正弦波与噪声叠加而成。它的作用是让「种子入土」
   与「点燃纸卷」两处仪式动作先有声音反馈，把接口与调用链路打通。

   正式音效应由声音设计师产出后替换同名 wav 文件——调用方零改动。

只依赖 Python 标准库，运行：
    python3 tool/generate_audio_assets.py
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def write_wav(name, samples):
    """把 -1.0~1.0 的浮点样本写成 16bit 单声道 wav。"""
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    frames = bytearray()
    for value in samples:
        clipped = max(-1.0, min(1.0, value))
        frames += struct.pack("<h", int(clipped * 32000))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(frames))
    print(f"  {name}  {len(samples) / SAMPLE_RATE:.2f}s  {len(frames)} 字节")


def match_strike(duration=0.42):
    """划火柴：一小段带衰减的噪声，尾部留一点细碎的噼啪。

    刻意做得短而轻——这是「点燃」而不是「爆炸」。
    """
    total = int(SAMPLE_RATE * duration)
    rng = random.Random(20260316)
    samples = []
    # 一阶低通，把白噪声磨成「沙」而不是「嘶」
    previous = 0.0
    for i in range(total):
        t = i / total
        noise = rng.uniform(-1.0, 1.0)
        previous = previous * 0.72 + noise * 0.28  # 低通
        # 起手极快、衰减平滑
        envelope = math.exp(-9.0 * t) * (1.0 - math.exp(-140.0 * t))
        # 尾部加几粒火星
        if t > 0.55 and rng.random() < 0.0025:
            samples.append(rng.uniform(-0.22, 0.22))
            continue
        samples.append(previous * envelope * 0.42)
    return samples


def soft_chime(duration=1.05):
    """种子入土 / 事情完成：两声很轻的钟音，五度上行。

    用基频加两个泛音模拟钟感，幅度压得很低——日记应用里不该有提示音式的尖锐感。
    """
    total = int(SAMPLE_RATE * duration)
    # C5 与 G5
    notes = [(523.25, 0.0), (783.99, 0.16)]
    samples = [0.0] * total

    for frequency, offset in notes:
        start = int(SAMPLE_RATE * offset)
        for i in range(start, total):
            t = (i - start) / SAMPLE_RATE
            if t < 0.0:
                continue
            envelope = math.exp(-4.2 * t) * (1.0 - math.exp(-260.0 * t))
            value = (
                math.sin(2 * math.pi * frequency * t) * 1.00
                + math.sin(2 * math.pi * frequency * 2.01 * t) * 0.28
                + math.sin(2 * math.pi * frequency * 3.02 * t) * 0.12
            )
            samples[i] += value * envelope * 0.16

    return samples


def main():
    print("生成占位音效到 assets/audio/")
    write_wav("match_strike.wav", match_strike())
    write_wav("seed_landing.wav", soft_chime())
    print("完成。正式音效请替换同名文件。")


if __name__ == "__main__":
    main()
