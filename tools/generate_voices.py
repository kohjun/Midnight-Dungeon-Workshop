#!/usr/bin/env python3
"""손님 모험가 6인 더빙 생성기 → assets/voices/<언어>/<모험가>_<대사>.mp3|wav

    python tools/generate_voices.py            # 없는 파일만 만든다
    python tools/generate_voices.py --force    # 전부 다시 만든다
    python tools/generate_voices.py --procedural   # edge-tts 를 쓰지 않고 절차적 음성만

대사 (data/audio.lua 의 voice.keys):
  greet_1 · greet_2      — 입장/흥정 한마디 (아래 GREETS, 화면 대사는 유물마다 달라 더빙은 짧은 인사로 둔다)
  caught_forgery · caught_curse · caught_crack — 결함·위조를 들킨 직후 대사 (data/locales/<언어>/guild.lua 와 같은 문장)
1) edge-tts (없으면 pip install edge-tts 시도, 네트워크 필요): 캐릭터별 음성·음높이·빠르기 매핑(VOICES) → .mp3
2) 설치·네트워크가 안 되면 캐릭터별 기본 음높이·포만트로 웅얼거리는 절차적 음성(.wav, 표준 라이브러리만)으로 대신한다.
한 대사는 한 형식만 남긴다 (새로 만들면 다른 확장자 파일은 지운다). 게임(systems/VoiceOver)은 ogg → mp3 → wav 순으로 찾는다.
"""

import asyncio
import io
import math
import os
import random
import re
import struct
import subprocess
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voices")
IDS = ("bern", "rina", "ellen", "thorin", "kain", "cedric")
SR = 22050

GREETS = {
    "ko": {
        "bern": ("강철의 베른이오. 오늘도 쓸 만한 걸 들고 왔지.", "값만 제대로 쳐 주시오, 사장."),
        "rina": ("쉿, 이번 건 진짜 귀한 거예요.", "흥정은 짧게 하죠? 저도 바쁘거든요."),
        "ellen": ("저, 실례합니다. 감정 좀 부탁드려도 될까요?", "스승님 창고에서 나온 물건이에요. 아마도요."),
        "thorin": ("드워프 대장장이 토린이다. 쇠 보는 눈은 내가 낫지.", "흥, 이 정도 물건이면 값을 후하게 쳐야 할 거다."),
        "kain": ("조용히 거래하지.", "출처는 묻지 마라. 값만 말해."),
        "cedric": ("후우, 가문의 물건을 내놓게 될 줄이야.", "신사답게, 적당한 값이면 됩니다."),
    },
    "en": {
        "bern": ("Bern of the Steel. Brought you something worth your while.", "Just give me a fair price, boss."),
        "rina": ("Psst, this one's a real find.", "Let's keep the haggling short. I'm busy too."),
        "ellen": ("Um, excuse me. Could you appraise this for me?", "It's from my master's storeroom. I think."),
        "thorin": ("Thorin, dwarf smith. I know iron better than anyone.", "Hmph. A piece like this deserves a generous price."),
        "kain": ("Let's keep this quiet.", "Don't ask where it came from. Just name a price."),
        "cedric": ("Haah. To think I'd be selling the family heirlooms.", "As gentlemen, a reasonable price will do."),
    },
}

# edge-tts 음성 매핑: (음성, 음높이, 빠르기)
VOICES = {
    "ko": {
        "bern": ("ko-KR-InJoonNeural", "-8Hz", "-6%"), "rina": ("ko-KR-SunHiNeural", "+6Hz", "+8%"),
        "ellen": ("ko-KR-SunHiNeural", "-3Hz", "-8%"), "thorin": ("ko-KR-InJoonNeural", "-18Hz", "-10%"),
        "kain": ("ko-KR-InJoonNeural", "-12Hz", "-2%"), "cedric": ("ko-KR-InJoonNeural", "+0Hz", "-14%"),
    },
    "en": {
        "bern": ("en-US-GuyNeural", "-6Hz", "-4%"), "rina": ("en-US-JennyNeural", "+4Hz", "+8%"),
        "ellen": ("en-GB-SoniaNeural", "-2Hz", "-6%"), "thorin": ("en-GB-RyanNeural", "-14Hz", "-8%"),
        "kain": ("en-US-ChristopherNeural", "-8Hz", "+0%"), "cedric": ("en-GB-ThomasNeural", "+0Hz", "-12%"),
    },
}

# 절차적 음성: (기본 음높이 Hz, 초당 음절, 포만트 배율)
PROCEDURAL = {
    "bern": (108, 8.5, 0.95), "rina": (220, 11.5, 1.15), "ellen": (196, 8.5, 1.1),
    "thorin": (86, 7.5, 0.85), "kain": (98, 9.0, 0.9), "cedric": (124, 7.5, 1.0),
}
VOWELS = ((730, 1090), (530, 1840), (270, 2290), (570, 840), (300, 870))   # a e i o u 포만트 근사


def caught_lines(lang):
    """data/locales/<lang>/guild.lua 의 adventurers.<id>.caught 문장 (따옴표 벗김)."""
    text = io.open(os.path.join(ROOT, "data", "locales", lang, "guild.lua"), encoding="utf-8").read()
    lines = {}
    for aid in IDS:
        block = re.search(r"\b%s = \{.*?caught = \{(.*?)\n\s*\}" % aid, text, re.S)
        found = dict(re.findall(r'(\w+) = "((?:[^"\\]|\\.)*)"', block.group(1))) if block else {}
        for kind in ("forgery", "curse", "crack"):
            line = found.get(kind, "").replace('\\"', "").strip()
            lines[(aid, "caught_" + kind)] = line
    return lines


def script(lang):
    lines = caught_lines(lang)
    for aid in IDS:
        for i, line in enumerate(GREETS[lang][aid], 1):
            lines[(aid, "greet_%d" % i)] = line
    return lines


def babble(text, aid, seed):
    """캐릭터 음높이·포만트로 문장 길이만큼 웅얼거리는 음성 (16-bit mono WAV 바이트)."""
    base, rate, shift = PROCEDURAL[aid]
    rng = random.Random(seed)
    count = max(4, min(30, len(text.replace(" ", "")) // 2))
    samples = []
    for i in range(count):
        dur = rng.uniform(0.75, 1.25) / rate
        f1, f2 = VOWELS[rng.randrange(len(VOWELS))]
        f1, f2 = f1 * shift, f2 * shift
        pitch = base * (1.0 + 0.12 * math.sin(i * 0.9) - 0.15 * i / count) * rng.uniform(0.95, 1.05)
        n = int(dur * SR)
        phase = 0.0
        for k in range(n):
            t = k / n
            env = min(1.0, t * 12) * (1 - t) ** 0.6
            phase += 2 * math.pi * pitch / SR
            value = 0.0
            for h in range(1, 14):          # 성대 배음을 포만트 두 봉우리로 거른다
                f = pitch * h
                gain = math.exp(-((f - f1) / 160) ** 2) + 0.6 * math.exp(-((f - f2) / 240) ** 2) + 0.05 / h
                value += gain * math.sin(phase * h)
            if k < n * 0.12:                # 자음처럼 짧은 숨소리
                value += rng.uniform(-0.6, 0.6) * (1 - k / (n * 0.12))
            samples.append(value * env * 0.18)
        samples.extend([0.0] * int(SR * rng.uniform(0.02, 0.05)))
    peak = max(1e-6, max(abs(v) for v in samples))
    out = io.BytesIO()
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v / peak * 0.85 * 32767)) for v in samples))
    return out.getvalue()


def edge_module():
    try:
        import edge_tts
        return edge_tts
    except ImportError:
        print("edge-tts not installed - trying: pip install edge-tts")
        try:
            subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "edge-tts"], check=True, timeout=300)
            import edge_tts
            return edge_tts
        except Exception as err:      # 설치 불가 → 절차적 음성
            print("edge-tts unavailable (%s) - using procedural voices" % err)
            return None


async def edge_save(edge_tts, text, voice, pitch, rate, path):
    await edge_tts.Communicate(text, voice, rate=rate, pitch=pitch).save(path)


def clear_other(base, keep):
    for ext in (".ogg", ".mp3", ".wav"):
        if ext != keep and os.path.exists(base + ext):
            os.remove(base + ext)


def main():
    force = "--force" in sys.argv
    edge_tts = None if "--procedural" in sys.argv else edge_module()
    made = {"edge": 0, "procedural": 0, "kept": 0}
    for lang in ("ko", "en"):
        os.makedirs(os.path.join(OUT, lang), exist_ok=True)
        for index, ((aid, key), text) in enumerate(sorted(script(lang).items())):
            base = os.path.join(OUT, lang, "%s_%s" % (aid, key))
            if not force and any(os.path.exists(base + ext) for ext in (".ogg", ".mp3", ".wav")):
                made["kept"] += 1
                continue
            if edge_tts is not None and text:
                voice, pitch, rate = VOICES[lang][aid]
                try:
                    asyncio.run(edge_save(edge_tts, text, voice, pitch, rate, base + ".mp3"))
                    clear_other(base, ".mp3")
                    made["edge"] += 1
                    print("wrote voices/%s/%s_%s.mp3 (%s)" % (lang, aid, key, voice))
                    continue
                except Exception as err:          # 네트워크 등 → 이 대사만 절차적 음성
                    print("edge-tts failed for %s/%s_%s: %s" % (lang, aid, key, err))
                    if os.path.exists(base + ".mp3"):
                        os.remove(base + ".mp3")
            with open(base + ".wav", "wb") as f:
                f.write(babble(text or key, aid, 5000 + index + (0 if lang == "ko" else 500)))
            clear_other(base, ".wav")
            made["procedural"] += 1
            print("wrote voices/%s/%s_%s.wav (procedural)" % (lang, aid, key))
    print("done: %(edge)d edge-tts, %(procedural)d procedural, %(kept)d kept" % made)


if __name__ == "__main__":
    main()
