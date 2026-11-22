"""'스승의 흔적' 캠페인 효과음 합성 (tools/generate_audio.py 가 SOUNDS 맨 끝에 붙인다).

    seal_clue_found : UV 렌즈 아래 드러난 스승의 은빛 인장 — 열린 화음으로 솟는 맑은 은빛 종 + 유리 하모니카 맥놀이
                      + 높은 유리 반짝임 꼬리, 신비롭지만 보람 있게                                                    (1.0초)
    master_toll     : 최종 보스 '균열의 잔영' 등장 — 깊은 조종(弔鐘) 한 번이 대성당 잔향으로 번지고,
                      아래로 낮은 균열 드론 · 땅울림 · 신음 · 차원이 갈라지는 지직거림                                 (2.4초)
    aegis_break     : 보랏빛 균열 아이기스 파훼 — 날카로운 균열 + 결정막이 유리처럼 산산조각 + 묵직한 저음 충격
                      + 마력이 흩어지며 가라앉는 하강음                                                                 (0.9초)

시드는 generate_audio.py 의 SOUNDS 순서(1000 + 순번)라 여기 소리는 반드시 맨 끝에 붙인다 — 기존 파일이 바이트 단위로 그대로다.
"""

import math

from audio_dsp import SR, TAU, seconds, decay, lowpass, highpass, sweep, bell, mix, shaped, white

SILVER = ((1.0, 1.0), (2.0, 0.3), (3.0, 0.12), (4.2, 0.05))           # 거의 배음 — 첼레스타·유리 같은 은빛 종
CHURCH = ((0.5, 0.5), (1.0, 1.0), (1.183, 0.42), (1.506, 0.3), (2.0, 0.6), (2.514, 0.2), (2.662, 0.16), (3.011, 0.13),
          (4.166, 0.08), (5.433, 0.05))                                 # 큰 종: 험 · 프라임 · 단3도 티어스 · 5도 · 노미널 …
GLASS = ((1.0, 1.0), (2.32, 0.5), (4.25, 0.25))                        # 얇은 결정판의 어긋난 배음 (4.7kHz × 4.25 < 나이퀴스트)


# ── 공용 ────────────────────────────────────────────────────

def fade_tail(samples, duration):
    """끝 duration 초를 부드럽게 줄인다 (길게 울리는 종이 버퍼 끝에서 뚝 끊기지 않게)."""
    count = max(1, seconds(duration))
    start = len(samples) - count
    return [value if i < start else value * ((len(samples) - i) / count) ** 2 for i, value in enumerate(samples)]


def hall(samples, delays=(0.0297, 0.0371, 0.0411, 0.0437), feedback=0.8, damp=0.4):
    """간단한 슈뢰더 잔향: 되먹임 안에서 고역을 깎는 병렬 콤 필터 4개의 평균 (대성당 같은 어두운 꼬리)."""
    out = [0.0] * len(samples)
    for delay in delays:
        size = seconds(delay)
        buf, idx, low = [0.0] * size, 0, 0.0
        for i, value in enumerate(samples):
            echo = buf[idx]
            low = echo * (1 - damp) + low * damp
            buf[idx] = value + low * feedback
            idx = (idx + 1) % size
            out[i] += echo / len(delays)
    return out


def glass_hum(freq, detune, duration, attack):
    """유리 하모니카: 살짝 어긋난 두 사인의 맥놀이 (느린 어택, 끝까지 사그라진다)."""
    out = []
    for k in range(seconds(duration)):
        t = k / SR
        env = min(1.0, t / attack) * (1 - t / duration) ** 1.4
        out.append(env * (math.sin(TAU * freq * t) + math.sin(TAU * (freq + detune) * t)))
    return out


def swept_noise(rng, duration, f0, f1):
    """차단 주파수가 f0 → f1 로 미끄러지는 1차 저역 통과 소음 (휙 가라앉는 바람)."""
    out, y, count = [], 0.0, seconds(duration)
    for i in range(count):
        cutoff = f0 + (f1 - f0) * (i / count) ** 0.6
        y += (1.0 - math.exp(-TAU * cutoff / SR)) * (rng.uniform(-1.0, 1.0) - y)
        out.append(y)
    return out


# ── 효과음 ──────────────────────────────────────────────────

def seal_clue_found(rng):
    """은빛 인장 발견: 렌즈에 걸리는 은빛 번쩍 + 3도 없는 열린 화음(A5 · E6 · A6 · B6)으로 솟는 맑은 종
    + 유리 하모니카 맥놀이(A4 · E5) + 높은 유리 반짝임 꼬리 (1.0초)."""
    glint = shaped(highpass(white(rng, seconds(0.04)), 6500), lambda u: (1 - u) ** 2)
    layers = [(0.0, glint, 0.14)]
    for start, freq, gain in ((0.0, 880.0, 0.34), (0.06, 1318.51, 0.3), (0.12, 1760.0, 0.27), (0.19, 1975.53, 0.32)):
        layers.append((start, shaped(bell(freq, 1.0 - start, 4.6, SILVER), lambda u: 1 - u ** 4), gain))
    layers += [(0.02, glass_hum(440.0, 1.6, 0.96, 0.18), 0.09), (0.05, glass_hum(659.25, 2.1, 0.9, 0.2), 0.08)]
    for i in range(10):     # 유리 반짝임 꼬리: 높은 음이 점점 드물고 작게
        freq = rng.choice((3520.0, 3951.07, 4186.01, 4698.64, 5274.04)) * rng.uniform(0.997, 1.003)
        sparkle = shaped(bell(freq, 0.16, 20.0, ((1.0, 1.0), (2.0, 0.2))), lambda u: 1 - u)
        layers.append((0.17 + i * 0.066 + rng.uniform(0.0, 0.024), sparkle, 0.08 * (1 - i / 13)))
    air = shaped(highpass(white(rng, seconds(0.8)), 7000), lambda u: min(1.0, u * 5) * (1 - u) ** 2)
    layers.append((0.12, air, 0.09))
    return mix(1.0, *layers)


def master_toll(rng):
    """최종 보스 등장: 큰 종(A2 프라임 · A3 노미널)을 무겁게 한 번 치는 깊은 조종이 대성당 잔향으로 번지고,
    아래로 맥동하는 균열 드론 · 땅울림 · 내려앉는 신음 · 차원이 갈라지는 지직거림 (2.4초)."""
    length = 2.4
    strike = shaped(lowpass(white(rng, seconds(0.07)), 1500), lambda u: (1 - u) ** 3)     # 종을 치는 순간의 둔탁한 타격
    clang = shaped(bell(747.0, 0.35, 12.0, ((1.0, 1.0), (1.32, 0.6), (1.87, 0.4), (2.71, 0.25))), lambda u: 1 - u)
    toll = bell(110.0, length, 1.05, CHURCH)
    drone = []
    for k in range(seconds(length)):
        t = k / SR
        env = min(1.0, t / 0.35) * min(1.0, (length - t) / 0.8) * (0.75 + 0.25 * math.sin(TAU * 1.6 * t))
        drone.append(env * sum((math.sin(TAU * 55.0 * n * t) + 0.8 * math.sin(TAU * 55.7 * n * t + n)) / n for n in range(1, 6)))
    rumble = shaped(lowpass(lowpass(white(rng, seconds(length)), 150), 110), lambda u: min(1.0, u * 6) * (1 - u) ** 1.2)
    groan = shaped(sweep(96, 47, 1.7, curve=0.8), lambda u: math.sin(math.pi * u) ** 1.5)
    layers = [(0.0, strike, 0.5), (0.0, clang, 0.16), (0.0, toll, 0.6), (0.0, hall(toll), 0.9),
              (0.0, lowpass(drone, 380), 0.2), (0.0, rumble, 3.0), (0.4, groan, 0.16)]
    for _ in range(7):      # 차원이 갈라지는 지직거림
        size = seconds(rng.uniform(0.01, 0.035))
        tear = lowpass(highpass([rng.uniform(-1, 1) * (1 - j / size) ** 2 for j in range(size)], 900), 3200)
        layers.append((rng.uniform(0.45, 1.9), tear, rng.uniform(0.12, 0.28)))
    return fade_tail(highpass(mix(length, *layers), 28), 0.5)          # 28Hz 아래(직류·초저역)는 걷어 낸다


def aegis_break(rng):
    """균열 아이기스 파훼: 날카로운 균열 → 결정 파편이 처음에 몰렸다 잦아들며 산산조각(늦게 구르는 작은 조각까지)
    + 파쇄 소음 + 묵직한 저음 충격 + 마력이 흩어지며 가라앉는 보랏빛 하강음 (0.9초)."""
    crack = shaped(highpass(white(rng, seconds(0.025)), 2500), lambda u: (1 - u) ** 2)
    thump = shaped(sweep(120, 36, 0.5, curve=0.5), lambda u: decay(u, 5))
    body = shaped(lowpass(white(rng, seconds(0.35)), 700), lambda u: decay(u, 7))
    crash = shaped(highpass(white(rng, seconds(0.5)), 3500), lambda u: decay(u, 6))
    layers = [(0.0, crack, 0.5), (0.0, thump, 0.95), (0.0, body, 0.9), (0.003, crash, 0.4)]
    for i in range(26):     # 결정 파편: 처음에 몰렸다가 잦아든다
        sparkle = shaped(bell(rng.uniform(1900.0, 4700.0), 0.3, rng.uniform(12.0, 22.0), GLASS), lambda u: 1 - u)
        layers.append((0.004 + (i / 26) ** 1.6 * 0.42 + rng.uniform(0.0, 0.012), sparkle, 0.13 * (1 - i / 34)))
    for i in range(6):      # 늦게 떨어져 구르는 작은 조각
        tinkle = shaped(bell(rng.uniform(3000.0, 4700.0), 0.12, 30.0, GLASS), lambda u: 1 - u)
        layers.append((0.46 + i * 0.055 + rng.uniform(0.0, 0.02), tinkle, 0.06 * (1 - i / 8)))
    whoosh = shaped(swept_noise(rng, 0.7, 5200, 260), lambda u: math.sin(math.pi * u) * (1 - u))
    fall = [a + b for a, b in zip(sweep(1250, 310, 0.5, curve=0.7), sweep(1262, 316, 0.5, curve=0.7))]
    layers += [(0.05, whoosh, 0.5), (0.06, shaped(fall, lambda u: math.sin(math.pi * u) * (1 - u)), 0.07)]
    return mix(0.9, *layers)


SOUNDS = {
    "seal_clue_found": (seal_clue_found, "sfx", SR, 0.8, False),
    "master_toll": (master_toll, "sfx", SR, 0.9, False),
    "aegis_break": (aegis_break, "sfx", SR, 0.95, False),
}
