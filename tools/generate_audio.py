#!/usr/bin/env python3
"""심야 던전 공방 효과음 · 루프 · 배경음 생성기 (낮·밤 전용 배경음과 앰비언스, 용광로 오버클럭·UV 적발음은 tools/audio_scenes.py,
'스승의 흔적' 캠페인의 은빛 인장 · 최종 보스 조종 · 아이기스 파훼음은 tools/audio_trace.py).

    python tools/generate_audio.py        (프로젝트 루트에서든 어디서든 실행 가능)

외부 패키지 없이 표준 라이브러리 wave / math / struct / random 만 사용한다.
출력: assets/sfx/*.wav (44.1kHz 16-bit mono), assets/bgm/*.wav (22.05kHz 16-bit mono 루프)
같은 시드로 합성하므로 다시 실행해도 같은 파일이 나온다 — 시드는 SOUNDS 순서라 새 소리는 반드시 끝에 붙인다
(기존 파일이 바이트 단위로 그대로 유지된다). 게임 쪽 목록은 data/audio.lua.
"""

import math
import random
import struct
import wave

import audio_scenes
import audio_trace
from audio_dsp import SR, BGM_SR, TAU, seconds, decay, lowpass, highpass, sweep, bell, mix, shaped, loop_crossfade, white  # noqa: F401 (합성 공용 도구)

_PARTS = __file__.replace("\\", "/").rsplit("/", 2)
# 프로젝트 루트: 절대 경로(.../tools/generate_audio.py) / "tools/generate_audio.py" / "generate_audio.py" 실행 모두 지원
ROOT = _PARTS[0] if len(_PARTS) == 3 else ("." if len(_PARTS) == 2 else "..")


# ── 효과음 ──────────────────────────────────────────────────

def ui_click(rng):
    tone = shaped(sweep(1500, 850, 0.06), lambda t: decay(t, 7))
    tick = shaped(highpass(white(rng, seconds(0.012)), 3000), lambda t: 1 - t)
    return mix(0.07, (0, tone, 0.8), (0, tick, 0.5))


def uv_hum(_rng):
    """1초 루프: 모든 성분이 정수 주기라 이음매가 없다."""
    out = []
    for i in range(seconds(1.0)):
        t = i / SR
        tremolo = 0.78 + 0.22 * math.sin(TAU * 6 * t)
        hum = math.sin(TAU * 110 * t) + 0.5 * math.sin(TAU * 220 * t) + 0.3 * math.sin(TAU * 330 * t)
        shimmer = 0.16 * math.sin(TAU * 1760 * t) * (0.5 + 0.5 * math.sin(TAU * 9 * t))
        out.append(hum * tremolo * 0.5 + shimmer)
    return out


def scrub(rng):
    """0.6초 루프: 왕복 두 번의 솔질 소리."""
    overlap = seconds(0.06)
    noise = highpass(lowpass(white(rng, seconds(0.6) + overlap), 5200), 900)
    noise = loop_crossfade(noise, overlap)
    count = len(noise)
    return [value * (0.25 + 0.75 * math.sin(math.pi * 2 * i / count) ** 2) for i, value in enumerate(noise)]


def flaw_found(rng):
    crack = shaped(highpass(white(rng, seconds(0.03)), 2500), lambda t: 1 - t)
    return mix(0.55, (0, crack, 0.5), (0.0, bell(880, 0.3, 9), 0.7), (0.11, bell(1320, 0.42, 7), 0.8))


def coin_buy(_rng):
    partials = ((1.0, 1.0), (1.51, 0.6), (2.03, 0.35), (2.74, 0.2))
    return mix(0.36, (0, bell(2100, 0.2, 16, partials), 0.7), (0.07, bell(2650, 0.28, 13, partials), 0.8))


def forge_charge(rng):
    duration = 0.9
    count = seconds(duration)
    noise, out, y = white(rng, count), [], 0.0
    phase = 0.0
    for i in range(count):
        t = i / count
        cutoff = 200 + 5200 * t * t                     # 점점 열리는 필터
        alpha = 1.0 - math.exp(-TAU * cutoff / SR)
        y += alpha * (noise[i] - y)
        phase += TAU * (70 + 260 * t * t) / SR
        tone = math.sin(phase) + 0.4 * math.sin(phase * 2)
        throb = 0.6 + 0.4 * math.sin(TAU * (6 + 22 * t) * t)
        out.append((y * 0.9 + tone * 0.5 * throb) * (0.15 + 0.85 * t))
    return out


def forge_success(rng):
    shimmer = shaped(highpass(white(rng, seconds(0.5)), 6000), lambda t: (1 - t) ** 2)
    notes = [(0.0, 523.25), (0.07, 659.25), (0.14, 783.99), (0.21, 1046.5)]
    layers = [(start, bell(freq, 0.7, 4.5), 0.55) for start, freq in notes]
    return mix(0.95, (0.0, shimmer, 0.25), *layers)


def forge_fail(rng):
    boom = shaped(sweep(130, 34, 0.8, curve=0.5), lambda t: decay(t, 4))
    blast = shaped(lowpass(white(rng, seconds(0.8)), 1400), lambda t: decay(t, 5))
    crackle = [value if rng.random() < 0.04 else 0.0 for value in white(rng, seconds(0.7))]
    crackle = shaped(crackle, lambda t: (1 - t) ** 2)
    return mix(0.9, (0, boom, 0.9), (0, blast, 0.9), (0.05, crackle, 0.35))


def shoot_bullet(rng):
    body = shaped(sweep(620, 170, 0.11, curve=0.6), lambda t: decay(t, 5))
    snap = shaped(highpass(white(rng, seconds(0.03)), 1800), lambda t: (1 - t) ** 2)
    return mix(0.12, (0, body, 0.8), (0, snap, 0.6))


def shoot_laser(_rng):
    out, phase, count = [], 0.0, seconds(0.18)
    for i in range(count):
        t = i / count
        freq = 1900 - 1450 * t ** 0.7 + 90 * math.sin(TAU * 38 * t)
        phase += TAU * freq / SR
        out.append((math.sin(phase) + 0.3 * math.sin(phase * 2)) * decay(t, 3.2))
    return out


def monster_hit(rng):
    thud = shaped(sweep(190, 65, 0.1, curve=0.5), lambda t: decay(t, 5))
    slap = shaped(lowpass(white(rng, seconds(0.03)), 2200), lambda t: 1 - t)
    return mix(0.11, (0, thud, 0.9), (0, slap, 0.6))


def overclock_on(rng):
    def saw(phase):
        return 2.0 * ((phase / TAU) % 1.0) - 1.0

    rise = lowpass(sweep(110, 880, 0.6, shape=saw, curve=1.6), 3800)
    rise = shaped(rise, lambda t: (0.2 + 0.8 * t) * (0.7 + 0.3 * math.sin(TAU * 14 * t)))
    alarm = shaped(sweep(880, 880, 0.3), lambda t: (0.5 + 0.5 * math.sin(TAU * 5 * t)) * (1 - t))
    hiss = shaped(highpass(white(rng, seconds(0.25)), 4000), lambda t: (1 - t) ** 2)
    return mix(0.85, (0, rise, 0.6), (0.52, alarm, 0.45), (0.52, hiss, 0.3))


def intro_thunder(rng):
    """인트로 번개: 날카로운 균열음 + 길게 굴러가는 저음."""
    crack = shaped(highpass(white(rng, seconds(0.12)), 2500), lambda t: (1 - t) ** 3)
    rumble = lowpass(lowpass(white(rng, seconds(2.6)), 180), 140)
    rumble = shaped(rumble, lambda t: min(1.0, t * 12) * decay(t, 2.2) * (0.7 + 0.3 * math.sin(TAU * 3 * t)))
    boom = shaped(sweep(70, 32, 1.4, curve=0.6), lambda t: decay(t, 3.5))
    return mix(2.7, (0, crack, 0.7), (0.04, rumble, 3.2), (0.03, boom, 0.6))


# ── 화면 전환 (ui/TransitionManager) ─────────────────────────

def seal_stamp(rng):
    """황동 도장이 밀랍·양피지 위에 쾅: 묵직한 저음 + 짧은 황동 울림 + 종이 탁."""
    thump = shaped(sweep(170, 46, 0.32, curve=0.45), lambda t: decay(t, 6))
    slap = shaped(lowpass(white(rng, seconds(0.07)), 1800), lambda t: (1 - t) ** 2)
    brass = bell(780, 0.45, 9, partials=((1.0, 1.0), (2.76, 0.5), (5.4, 0.25)))
    squish = shaped(lowpass(white(rng, seconds(0.18)), 600), lambda t: t * (1 - t) * 4)
    return mix(0.55, (0, thump, 1.0), (0, slap, 0.7), (0.005, brass, 0.3), (0.03, squish, 0.35))


def iris_brass(rng):
    """황동 조리개 기계음: 빨라지는 톱니 딸깍임 + 낮은 회전음 + 끝에 금속 울림."""
    clicks = []
    t, gap = 0.0, 0.075
    while t < 0.48:
        tick = shaped(highpass(white(rng, seconds(0.012)), 2600), lambda x: (1 - x) ** 2)
        tone = shaped(sweep(2300, 1700, 0.02), lambda x: decay(x, 9))
        clicks += [(t, tick, 0.6), (t, tone, 0.25)]
        t += gap
        gap = max(0.028, gap * 0.82)
    whir = shaped(sweep(140, 95, 0.55), lambda x: math.sin(math.pi * x) * 0.8)
    ring = bell(1240, 0.35, 10, partials=((1.0, 1.0), (2.3, 0.4)))
    return mix(0.8, (0, whir, 0.35), (0.47, ring, 0.35), *clicks)


def shutter_slam(rng):
    """무거운 철제 셔터가 쾅: 깊은 충격 + 금속판 울림 + 덜컹이는 잔향과 먼지."""
    boom = shaped(sweep(95, 28, 0.9, curve=0.5), lambda t: decay(t, 4.5))
    crash = shaped(lowpass(white(rng, seconds(0.5)), 900), lambda t: decay(t, 7))
    plate = bell(176, 1.3, 2.6, partials=((1.0, 1.0), (2.41, 0.6), (3.93, 0.35), (5.1, 0.2)))
    rattle = [value if rng.random() < 0.03 else 0.0 for value in highpass(white(rng, seconds(0.6)), 1500)]
    rattle = shaped(rattle, lambda t: (1 - t) ** 2)
    return mix(1.4, (0, boom, 1.0), (0, crash, 0.8), (0.004, plate, 0.32), (0.08, rattle, 0.5))


def bolt_unlock(rng):
    """철제 빗장이 풀리는 소리: 끼익 미끄러지는 마찰음 + 철컥 + 짧은 울림."""
    scrape = lowpass(highpass(white(rng, seconds(0.38)), 700), 2600)
    scrape = shaped(scrape, lambda t: min(1.0, t * 8) * (1 - t) * (0.6 + 0.4 * math.sin(TAU * 31 * t)))
    squeal = shaped(sweep(620, 820, 0.36), lambda t: math.sin(math.pi * t) * 0.5)
    clack = shaped(highpass(white(rng, seconds(0.03)), 1200), lambda t: (1 - t) ** 3)
    thunk = shaped(sweep(240, 120, 0.12), lambda t: decay(t, 8))
    ring = bell(620, 0.4, 7, partials=((1.0, 1.0), (2.7, 0.35)))
    return mix(0.85, (0, scrape, 0.6), (0.02, squeal, 0.18), (0.38, clack, 0.8), (0.38, thunk, 0.7), (0.39, ring, 0.25))


# ── 배경음 ──────────────────────────────────────────────────

def workshop_ambient(rng):
    """어두운 공방: 낮은 드론 + 단조 패드 + 용광로 바람 + 불티 + 먼 금속음. 16초 루프.

    모든 음정은 1/16 Hz 의 배수(정수 주기)이고, 소음은 교차 페이드, 이벤트는 버퍼를 돌아 감기므로 이음매가 없다.
    """
    length = 16
    count = seconds(length, BGM_SR)
    out = [0.0] * count
    for i in range(count):
        t = i / BGM_SR
        swell = 0.75 + 0.25 * math.sin(TAU * t / 16)
        drone = math.sin(TAU * 55 * t) + 0.6 * math.sin(TAU * 82.5 * t) * (0.6 + 0.4 * math.sin(TAU * t / 8))
        pad = (math.sin(TAU * 110 * t) + 0.8 * math.sin(TAU * 130.8125 * t) + 0.7 * math.sin(TAU * 164.8125 * t))
        pad *= 0.5 + 0.5 * math.sin(TAU * (t / 16 * 3) + 1.3)
        out[i] = drone * 0.32 * swell + pad * 0.07

    overlap = seconds(1.0, BGM_SR)
    wind = lowpass(lowpass(white(rng, count + overlap), 420, BGM_SR), 420, BGM_SR)
    wind = loop_crossfade(wind, overlap)
    for i in range(count):
        gust = 0.55 + 0.45 * math.sin(TAU * (i / count) * 2 + 0.7)
        out[i] += wind[i] * 2.2 * gust

    def add_event(start, samples, gain):
        offset = seconds(start, BGM_SR)
        for j, value in enumerate(samples):
            out[(offset + j) % count] += value * gain

    for _ in range(46):     # 불티 튀는 소리
        size = seconds(rng.uniform(0.004, 0.02), BGM_SR)
        spark = [rng.uniform(-1, 1) * (1 - j / size) ** 2 for j in range(size)]
        add_event(rng.uniform(0, length), highpass(spark, 1500, BGM_SR), rng.uniform(0.05, 0.16))
    for _ in range(5):      # 멀리서 울리는 금속음
        freq = rng.choice([392.0, 523.25, 587.33, 698.46])
        size = seconds(2.4, BGM_SR)
        ping = [math.sin(TAU * freq * j / BGM_SR) * decay(j / BGM_SR, 2.2)
                + 0.4 * math.sin(TAU * freq * 2.76 * j / BGM_SR) * decay(j / BGM_SR, 4.0) for j in range(size)]
        add_event(rng.uniform(0, length), ping, rng.uniform(0.03, 0.06))
    return out


# ── 타이틀 전용 절차적 오디오 3종 ─────────────────────────────

def title_ambience(rng):
    """타이틀 전용: 잔잔한 밤비 + 절벽 밤바람 + 간헐적 빗방울 틱. 12초 이음매 없는 루프."""
    length = 12
    count = seconds(length, BGM_SR)
    overlap = seconds(1.0, BGM_SR)

    # 1) 낮은 절벽 밤바람 (이중 저역 필터 + 느린 돌풍 파형)
    wind = lowpass(lowpass(white(rng, count + overlap), 310, BGM_SR), 260, BGM_SR)
    wind = loop_crossfade(wind, overlap)
    # 2) 잔잔한 밤비 (대역 통과 노이즈)
    rain = highpass(lowpass(white(rng, count + overlap), 4100, BGM_SR), 880, BGM_SR)
    rain = loop_crossfade(rain, overlap)

    out = [0.0] * count
    for i in range(count):
        phase = i / count
        gust = 0.55 + 0.30 * math.sin(TAU * phase) + 0.15 * math.sin(TAU * phase * 3 + 0.9)
        rain_mod = 0.85 + 0.15 * math.sin(TAU * phase * 2 + 1.4)
        out[i] = wind[i] * 2.4 * gust + rain[i] * 0.55 * rain_mod

    # 3) 돌길 위 잔잔한 빗방울 틱 (루프 경계 감기)
    for _ in range(38):
        freq = rng.uniform(950.0, 2200.0)
        size = seconds(0.035, BGM_SR)
        offset = seconds(rng.uniform(0, length), BGM_SR)
        gain = rng.uniform(0.02, 0.06)
        for j in range(size):
            t = j / BGM_SR
            val = math.sin(TAU * freq * (1.0 + 3.5 * t) * t) * decay(t, 95.0)
            out[(offset + j) % count] += val * gain
    return out


def title_thunder(rng):
    """좌측 하늘 번개 뒤 0.4~1.2초 시차로 울리는 묵직한 저주파 천둥소리."""
    rumble = lowpass(lowpass(white(rng, seconds(3.5)), 165), 115)
    rumble = shaped(
        rumble,
        lambda t: min(1.0, t * 14.0) * (
            decay(t, 1.55) * 0.85 + 0.45 * math.exp(-((t - 0.34) / 0.11) ** 2)
        ),
    )
    sub = shaped(sweep(58, 28, 2.2, curve=0.55), lambda t: min(1.0, t * 18.0) * decay(t, 1.9))
    crackle = shaped(lowpass(highpass(white(rng, seconds(0.45)), 380), 1500), lambda t: decay(t, 6.5))
    return mix(3.6, (0.0, crackle, 0.28), (0.02, rumble, 4.2), (0.04, sub, 0.55))


def sign_creak(rng):
    """나무 간판 스칠 때 짧은 나무 삐걱거림 + 미세한 쇠고리 울림."""
    dur = 0.32
    count = seconds(dur)
    out, phase = [], 0.0
    for i in range(count):
        t = i / count
        # 나무 마찰음: 245Hz -> 175Hz 하강 + 40Hz 스틱-슬립 진동
        freq = 245.0 - 70.0 * t + 28.0 * math.sin(TAU * 42.0 * t)
        phase += TAU * freq / SR
        saw = 2.0 * ((phase / TAU) % 1.0) - 1.0
        env = min(1.0, t * 12.0) * ((1.0 - t) ** 1.35)
        out.append(saw * env)
    wood = highpass(lowpass(out, 1450), 420)
    clink = bell(2350, 0.09, 32, partials=((1.0, 1.0), (2.42, 0.45)))
    grain = shaped(highpass(lowpass(white(rng, seconds(0.22)), 1600), 650), lambda t: math.sin(math.pi * t) * 0.35)
    return mix(0.35, (0.0, wood, 1.4), (0.01, clink, 0.25), (0.02, grain, 0.35))


# name: (합성 함수, 하위 폴더, 샘플레이트, 정규화 피크, 루프 여부)
SOUNDS = {
    "ui_click": (ui_click, "sfx", SR, 0.7, False),
    "uv_hum": (uv_hum, "sfx", SR, 0.6, True),
    "scrub": (scrub, "sfx", SR, 0.7, True),
    "flaw_found": (flaw_found, "sfx", SR, 0.8, False),
    "coin_buy": (coin_buy, "sfx", SR, 0.75, False),
    "forge_charge": (forge_charge, "sfx", SR, 0.8, False),
    "forge_success": (forge_success, "sfx", SR, 0.8, False),
    "forge_fail": (forge_fail, "sfx", SR, 0.9, False),
    "shoot_bullet": (shoot_bullet, "sfx", SR, 0.75, False),
    "shoot_laser": (shoot_laser, "sfx", SR, 0.7, False),
    "monster_hit": (monster_hit, "sfx", SR, 0.8, False),
    "overclock_on": (overclock_on, "sfx", SR, 0.8, False),
    "intro_thunder": (intro_thunder, "sfx", SR, 0.85, False),
    "workshop_ambient": (workshop_ambient, "bgm", BGM_SR, 0.6, True),
    "seal_stamp": (seal_stamp, "sfx", SR, 0.9, False),
    "iris_brass": (iris_brass, "sfx", SR, 0.75, False),
    "shutter_slam": (shutter_slam, "sfx", SR, 0.95, False),
    "bolt_unlock": (bolt_unlock, "sfx", SR, 0.8, False),
    # 타이틀 2.5D 전용 3종 (기존 18종 시드 불변을 위해 반드시 맨 뒤에 유지)
    "title_ambience": (title_ambience, "bgm", BGM_SR, 0.45, True),
    "title_thunder": (title_thunder, "sfx", SR, 0.88, False),
    "sign_creak": (sign_creak, "sfx", SR, 0.72, False),
}
SOUNDS.update(audio_scenes.SOUNDS)      # 끝에 붙인다 (기존 소리의 시드 = 순서 유지)
SOUNDS.update(audio_trace.SOUNDS)       # '스승의 흔적' 3종 — 그 뒤에 (위 36종의 시드는 그대로)


def write_wav(path, samples, rate, peak, loop):
    loudest = max(1e-9, max(abs(value) for value in samples))
    scale = peak / loudest
    fade = 0 if loop else min(len(samples) // 4, int(rate * 0.004))    # 딸깍임 방지 (루프는 그대로 이어져야 한다)
    frames = bytearray()
    for i, value in enumerate(samples):
        gain = scale
        if fade > 0:
            gain *= min(1.0, i / fade, (len(samples) - 1 - i) / fade)
        frames += struct.pack("<h", max(-32767, min(32767, int(value * gain * 32767))))
    try:
        out = wave.open(path, "wb")
    except FileNotFoundError:
        raise SystemExit("cannot write %s - run from the project and make sure assets/sfx and assets/bgm exist" % path)
    with out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(bytes(frames))


def main():
    for index, (name, (synth, folder, rate, peak, loop)) in enumerate(SOUNDS.items()):
        samples = synth(random.Random(1000 + index))
        path = "%s/assets/%s/%s.wav" % (ROOT, folder, name)
        write_wav(path, samples, rate, peak, loop)
        print("wrote %-34s %5.2fs%s" % ("assets/%s/%s.wav" % (folder, name), len(samples) / rate, "  (loop)" if loop else ""))
    print("done: %d sounds" % len(SOUNDS))


if __name__ == "__main__":
    main()
