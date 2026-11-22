"""낮·밤 전용 배경음 · 앰비언스와 용광로 오버클럭 · UV 적발 효과음 합성 (tools/generate_audio.py 가 SOUNDS 에 붙인다).

    day_ambience   : 벽난로 장작 타는 소리(갈색 소음 + 탁탁 튀는 불티 + 가끔 장작 터지는 소리) + 은은한 공방 잔향   (12초 루프)
    day_bgm        : 느리고 음울한 류트(카플러스-스트롱 현) 아르페지오 + 낮은 현악 패드, A 단조 72 BPM            (26.7초 루프)
    night_ambience : 던전 포탈의 낮고 불길한 저주파 진동 + 속삭이는 띠 소음 + 멀리서 울리는 신음                     (10초 루프)
    night_bgm      : 긴박한 저음 북(태고)·림·셰이커 리듬 + D 단조 저음 오스티나토 + 낮은 금관 드론, 108 BPM           (17.8초 루프)
    forge_heat · forge_overclock_ok · forge_shatter · uv_defect_reveal : 효과음

루프는 정수 주기 성분 · 교차 페이드 · 버퍼를 돌아 감는 이벤트(fold)로 이음매가 없다. 같은 시드면 같은 파일이 나온다.
"""

import math

from audio_dsp import SR, BGM_SR, TAU, seconds, decay, lowpass, highpass, sweep, bell, mix, shaped, loop_crossfade, white

A_MINOR = {"A2": 110.0, "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0, "A3": 220.0, "B3": 246.94,
           "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G#3": 207.65, "G#4": 415.3, "A4": 440.0}


def fold(buffer, count):
    """count 길이 루프로 감는다: count 를 넘친 꼬리를 머리에 더한다."""
    out = buffer[:count]
    for i in range(count, len(buffer)):
        out[i % count] += buffer[i]
    return out


def pluck(rng, freq, duration, rate, damping=0.994):
    """카플러스-스트롱 현 뜯는 소리 (류트)."""
    period = max(2, int(round(rate / freq)))
    buf = lowpass([rng.uniform(-1, 1) for _ in range(period)], 3000, rate)
    out, idx = [], 0
    for _ in range(int(duration * rate)):
        a, b = buf[idx], buf[(idx + 1) % period]
        out.append(a)
        buf[idx] = damping * 0.5 * (a + b)
        idx = (idx + 1) % period
    return out


def add_at(out, start, samples, gain, rate):
    offset = int(start * rate)
    for j, value in enumerate(samples):
        out[offset + j] += value * gain


# ── 낮 ──────────────────────────────────────────────────────

def day_ambience(rng):
    length = 12
    count = seconds(length, BGM_SR)
    overlap = seconds(1.0, BGM_SR)
    roar = lowpass(lowpass(white(rng, count + overlap), 300, BGM_SR), 260, BGM_SR)
    roar = loop_crossfade(roar, overlap)
    out = [0.0] * (count + seconds(1.0, BGM_SR))
    for i in range(count):
        t = i / BGM_SR
        breath = 0.7 + 0.2 * math.sin(TAU * t / 6) + 0.1 * math.sin(TAU * t / 4 + 1.1)     # 불길이 일렁인다
        out[i] = roar[i] * 3.2 * breath + 0.05 * math.sin(TAU * 49 * t) * (0.6 + 0.4 * math.sin(TAU * t / 12))
    for _ in range(170):    # 탁탁 튀는 불티
        size = seconds(rng.uniform(0.003, 0.014), BGM_SR)
        crack = [rng.uniform(-1, 1) * (1 - j / size) ** 2 for j in range(size)]
        add_at(out, rng.uniform(0, length), highpass(crack, 1800, BGM_SR), rng.uniform(0.04, 0.22), BGM_SR)
    for _ in range(6):      # 장작이 터지는 소리
        start = rng.uniform(0, length)
        thump = [math.sin(TAU * 120 * j / BGM_SR) * decay(j / BGM_SR, 22) for j in range(seconds(0.18, BGM_SR))]
        snap = highpass([rng.uniform(-1, 1) * decay(j / BGM_SR, 60) for j in range(seconds(0.05, BGM_SR))], 1200, BGM_SR)
        add_at(out, start, thump, 0.35, BGM_SR)
        add_at(out, start, snap, 0.5, BGM_SR)
    return fold(out, count)


def _pad_note(freq, t, harmonics=4):
    return sum(math.sin(TAU * freq * n * t) / n for n in range(1, harmonics + 1))


def day_bgm(rng):
    beat = 60 / 72
    bars = [("A2", ["A3", "C4", "E4"]), ("F3", ["F3", "A3", "C4"]), ("D3", ["D4", "F4", "A3"]), ("E3", ["E3", "G#3", "B3"]),
            ("A2", ["A3", "C4", "E4"]), ("C3", ["C4", "E4", "G3"]), ("D3", ["D4", "F4", "A3"]), ("E3", ["E4", "G#4", "B3"])]
    bar_len = beat * 4
    length = bar_len * len(bars)
    count = seconds(length, BGM_SR)
    out = [0.0] * (count + seconds(4, BGM_SR))
    patterns = [[0, 1, 2, 1, 0, 2, 1, 2], [0, 2, 1, 2, 0, 1, 2, 1]]
    for b, (root, chord) in enumerate(bars):
        start = b * bar_len + 0.06       # 루프 경계에 현 뜯는 소리가 걸리지 않게 살짝 늦춘다
        for step, index in enumerate(patterns[b // 4]):         # 8분음표 류트 아르페지오
            freq = A_MINOR[chord[index]]
            add_at(out, start + step * beat / 2 + rng.uniform(0, 0.012), pluck(rng, freq, 2.2, BGM_SR, 0.9965),
                   0.32 if step % 4 == 0 else 0.22, BGM_SR)
        add_at(out, start, pluck(rng, A_MINOR[root], 3.0, BGM_SR, 0.998), 0.4, BGM_SR)     # 마디 첫 박 저음 현
        size = seconds(bar_len + 1.2, BGM_SR)                                                # 현악 패드 (느린 어택)
        pad = [0.0] * size
        for j in range(size):
            t = j / BGM_SR
            env = min(1.0, t / 0.9) * (1.0 if t < bar_len else max(0.0, 1 - (t - bar_len) / 1.2))
            pad[j] = env * (_pad_note(A_MINOR[chord[0]] / 2, t) + 0.7 * _pad_note(A_MINOR[chord[1]] / 2, t))
        add_at(out, start, lowpass(pad, 900, BGM_SR), 0.055, BGM_SR)
    return fold(out, count)


# ── 밤 ──────────────────────────────────────────────────────

def night_ambience(rng):
    length = 10
    count = seconds(length, BGM_SR)
    overlap = seconds(1.0, BGM_SR)
    hiss = lowpass(highpass(white(rng, count + overlap), 600, BGM_SR), 1600, BGM_SR)
    hiss = loop_crossfade(hiss, overlap)
    out = [0.0] * (count + seconds(3, BGM_SR))
    for i in range(count):
        t = i / BGM_SR
        throb = 0.6 + 0.4 * math.sin(TAU * 0.5 * t)                                            # 포탈이 맥동한다
        out[i] = (math.sin(TAU * 36 * t) + 0.7 * math.sin(TAU * 54 * t + 0.4)) * 0.42 * throb \
            + hiss[i] * 0.9 * (0.5 + 0.5 * math.sin(TAU * t / 5 + 2.0))
    for _ in range(3):      # 멀리서 울리는 신음
        groan = shaped(sweep(rng.uniform(85, 100), rng.uniform(52, 62), 2.4, BGM_SR, curve=0.7), lambda x: math.sin(math.pi * x))
        groan = [v * (0.7 + 0.3 * math.sin(TAU * 7 * j / BGM_SR)) for j, v in enumerate(groan)]
        add_at(out, rng.uniform(0, length), groan, 0.22, BGM_SR)
    return fold(out, count)


def _drum(rng, rate):
    """낮은 북(태고): 음높이가 떨어지는 몸통 + 짧은 가죽 타격음."""
    body = shaped(sweep(115, 48, 0.32, rate, curve=0.5), lambda x: decay(x, 6))
    noise = shaped(lowpass(white(rng, seconds(0.05, rate)), 900, rate), lambda x: 1 - x)
    return [b + (noise[i] * 0.5 if i < len(noise) else 0.0) for i, b in enumerate(body)]


def night_bgm(rng):
    beat = 60 / 108
    bars = 8
    length = beat * 4 * bars
    count = seconds(length, BGM_SR)
    out = [0.0] * (count + seconds(2, BGM_SR))
    bass = [73.42, 73.42, 87.31, 82.41, 73.42, 73.42, 98.0, 87.31]       # D 단조 오스티나토 (8분음표)
    for bar in range(bars):
        start = bar * beat * 4
        hits = [0, 1.5, 2] if bar % 4 != 3 else [0, 1.5, 2, 3, 3.5]     # 4마디마다 몰아치는 필인
        for hit in hits:
            add_at(out, start + hit * beat, _drum(rng, BGM_SR), 0.9 if hit == 0 else 0.7, BGM_SR)
        for back in (1, 3):     # 림
            rim = highpass([rng.uniform(-1, 1) * decay(j / BGM_SR, 45) for j in range(seconds(0.08, BGM_SR))], 1800, BGM_SR)
            add_at(out, start + back * beat, rim, 0.28, BGM_SR)
        for sixteenth in range(16):     # 셰이커
            tick = highpass([rng.uniform(-1, 1) * decay(j / BGM_SR, 90) for j in range(seconds(0.03, BGM_SR))], 4000, BGM_SR)
            add_at(out, start + sixteenth * beat / 4, tick, 0.09 if sixteenth % 2 else 0.05, BGM_SR)
        for step, freq in enumerate(bass):
            note = [(_pad_note(freq, j / BGM_SR, 5)) * decay(j / BGM_SR, 5.5) for j in range(seconds(beat / 2, BGM_SR))]
            add_at(out, start + step * beat / 2, lowpass(note, 420, BGM_SR), 0.2, BGM_SR)
    for i in range(count):      # 낮은 금관 드론 (D2 + A2, 8마디에 한 번 부풀었다 가라앉는다)
        t = i / BGM_SR
        swell = 0.35 + 0.25 * math.sin(TAU * t / length - math.pi / 2)
        out[i] += (math.sin(TAU * 73.42 * t) + 0.5 * math.sin(TAU * 110.0 * t)) * 0.09 * swell
    return fold(out, count)


# ── 효과음 ──────────────────────────────────────────────────

def forge_heat(rng):
    """오버클럭 가열: 위로 치솟는 금속 공명 + 타닥이는 불티 (0.45초)."""
    rise = shaped(sweep(240, 980, 0.45, curve=1.6), lambda t: 0.25 + 0.75 * t ** 1.3)
    ring = shaped(sweep(240 * 2.76, 980 * 2.76, 0.45, curve=1.6), lambda t: 0.4 * t ** 2)
    crackle = [value if rng.random() < 0.05 else 0.0 for value in highpass(white(rng, seconds(0.45)), 2500)]
    return mix(0.47, (0, rise, 0.55), (0, ring, 0.3), (0, crackle, 0.45))


def forge_overclock_ok(rng):
    """오버클럭 대성공: 웅장한 모루 타격 + 깊은 울림 + 장조 종소리 상승 + 반짝임 (1.6초)."""
    anvil = bell(196.0, 1.6, 2.2, partials=((1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.93, 0.18)))
    thump = shaped(sweep(82, 42, 0.5, curve=0.6), lambda t: decay(t, 5))
    shimmer = shaped(highpass(white(rng, seconds(1.0)), 6500), lambda t: (1 - t) ** 2)
    chord = [(0.08, 392.0), (0.16, 493.88), (0.24, 587.33), (0.32, 783.99)]
    layers = [(0, anvil, 0.7), (0, thump, 0.8), (0.05, shimmer, 0.18)]
    layers += [(start, bell(freq, 1.2, 2.0), 0.22) for start, freq in chord]
    return mix(1.7, *layers)


def forge_shatter(rng):
    """오버클럭 파괴: 둔탁하고 무거운 파쇄음 + 튀는 파편 + 갈라지는 고음 + 낮은 여운 (1.3초)."""
    blast = shaped(lowpass(white(rng, seconds(0.9)), 900), lambda t: decay(t, 5))
    thump = shaped(sweep(70, 34, 0.6, curve=0.5), lambda t: decay(t, 4.5))
    shards = [value if rng.random() < 0.06 else 0.0 for value in highpass(white(rng, seconds(0.45)), 3000)]
    glass = [(0.02, 2093.0), (0.05, 2489.0), (0.09, 1760.0)]
    rumble = shaped(lowpass(lowpass(white(rng, seconds(1.2)), 160), 120), lambda t: (1 - t) * min(1, t * 8))
    layers = [(0, blast, 0.9), (0, thump, 0.9), (0.01, shards, 0.5), (0.1, rumble, 2.2)]
    layers += [(start, bell(freq, 0.4, 9.0, partials=((1.0, 1.0), (2.41, 0.5))), 0.12) for start, freq in glass]
    return mix(1.35, *layers)


def uv_defect_reveal(rng):
    """UV 결함·위조 적발: 날카롭게 치솟는 금속성 징 + 불협 단2도 종 + 둔탁한 낙인 (0.55초)."""
    zing = shaped(sweep(1600, 3300, 0.18, curve=0.5), lambda t: decay(t, 4) * (1 - t))
    clash = [a + b for a, b in zip(bell(1318.5, 0.5, 6.0), bell(1396.9, 0.5, 6.5))]
    tick = shaped(highpass(white(rng, seconds(0.02)), 3500), lambda t: 1 - t)
    brand = shaped(sweep(240, 150, 0.2, curve=0.6), lambda t: decay(t, 9))
    return mix(0.56, (0, tick, 0.5), (0, zing, 0.45), (0.03, clash, 0.28), (0.02, brand, 0.55))


def cursor_tap(rng):
    """망치 커서 클릭: 작은 망치로 쇠를 톡 — 짧은 금속 틱 + 낮은 종 한 겹 (0.09초, 연타해도 귀가 피로하지 않게 부드럽게)."""
    tick = shaped(lowpass(white(rng, seconds(0.012)), 5200), lambda t: (1 - t) ** 2)
    ring = shaped(bell(1760.0, 0.08, 38.0), lambda t: 1 - t)
    knock = shaped(sweep(420, 260, 0.05, curve=0.6), lambda t: decay(t, 14))
    return mix(0.34, (0, tick, 0.45), (0, knock, 0.4), (0.002, ring, 0.18))


def coin_tally(rng):
    """새벽 정산 카운트업: 동전이 짤랑짤랑 빠르게 쏟아지다 잦아든다 (1.0초)."""
    layers, t = [], 0.0
    for i in range(16):
        freq = rng.choice((2093.0, 2349.3, 2637.0, 2793.8)) * rng.uniform(0.98, 1.02)
        clink = shaped(bell(freq, 0.12, 30.0), lambda u: 1 - u)
        layers.append((t, clink, 0.30 * (1 - i / 22)))
        t += 0.075 * (0.7 + 0.3 * i / 15)
    thud = shaped(sweep(220, 140, 0.12, curve=0.6), lambda u: decay(u, 12))
    return mix(1.05, (0.0, thud, 0.25), *layers)


def shop_door_bell(rng):
    """새 손님: 가게 문 위 황동 종이 맑게 두 번 울리고 길게 여운 (1.3초)."""
    first = [a + b for a, b in zip(bell(1318.5, 1.2, 3.2), bell(1975.5, 1.2, 4.0))]
    second = [a + b for a, b in zip(bell(1396.9, 1.0, 3.6), bell(2093.0, 1.0, 4.5))]
    jingle = shaped(highpass(white(rng, seconds(0.05)), 4000), lambda u: (1 - u) ** 2)
    return mix(1.3, (0.0, jingle, 0.15), (0.0, first, 0.42), (0.16, second, 0.32))


def guest_footsteps_out(rng):
    """손님 퇴장: 나무 바닥 발걸음이 멀어진다 (5걸음, 1.6초)."""
    layers = []
    for i in range(5):
        knock = shaped(sweep(170, 95, 0.09, curve=0.7), lambda u: decay(u, 16))
        scuff = shaped(lowpass(white(rng, seconds(0.06)), 1800), lambda u: (1 - u) ** 3)
        gain = 0.62 * (1 - i * 0.17)
        layers.append((i * 0.3 + rng.uniform(-0.02, 0.02), knock, gain))
        layers.append((i * 0.3 + 0.01, scuff, gain * 0.35))
    return mix(1.6, *layers)


def supply_low(rng):
    """자원 부족 경고: 유리관 종이 딩-동 두 번 낮아지고, 꺼져 가는 마나 웅웅거림이 깔린다 (0.75초)."""
    high = shaped(bell(1046.5, 0.32, 7.0), lambda u: 1 - u)
    low = shaped(bell(784.0, 0.42, 6.0), lambda u: 1 - u)
    hum = shaped(sweep(230, 150, 0.6, curve=0.8), lambda u: decay(u, 4) * (0.6 + 0.4 * math.sin(u * 70)))
    tick = shaped(highpass(white(rng, seconds(0.015)), 3000), lambda u: (1 - u) ** 2)
    return mix(0.75, (0.0, tick, 0.2), (0.0, high, 0.42), (0.19, low, 0.44), (0.02, hum, 0.14))


def forge_dud(rng):
    """강화 실패(단계 유지·하락): 둔탁하게 먹히는 쇳소리 + 식어 가는 김 빠지는 소리 (0.8초)."""
    thud = shaped(sweep(150, 90, 0.25, curve=0.7), lambda u: decay(u, 7))
    clank = shaped(bell(310.0, 0.35, 14.0), lambda u: (1 - u) ** 2)
    rattle = shaped(lowpass(white(rng, seconds(0.12)), 900), lambda u: (1 - u) ** 3)
    hiss = shaped(highpass(white(rng, seconds(0.6)), 2600), lambda u: math.sin(u * math.pi) * 0.6 * (1 - u))
    return mix(0.8, (0.0, thud, 0.6), (0.0, clank, 0.32), (0.01, rattle, 0.25), (0.12, hiss, 0.22))


def midboss_horn(rng):
    """중간 보스 출현: 낮게 울리는 뿔피리 두 마디 + 북 한 번 (1.4초)."""
    def horn(freq, dur):
        out = []
        for k in range(seconds(dur)):
            t = k / SR
            env = min(1.0, t * 9) * min(1.0, (dur - t) * 4)
            vib = 1 + 0.006 * math.sin(TAU * 5.5 * t)
            out.append(env * (math.sin(TAU * freq * vib * t) + 0.45 * math.sin(TAU * 2 * freq * vib * t)
                              + 0.2 * math.sin(TAU * 3 * freq * vib * t)))
        return lowpass(out, 1400)
    drum = shaped(sweep(95, 55, 0.35, curve=0.6), lambda u: decay(u, 6))
    return mix(1.4, (0.0, drum, 0.7), (0.05, horn(110.0, 0.55), 0.34), (0.62, horn(98.0, 0.7), 0.38))


SOUNDS = {
    "day_ambience": (day_ambience, "bgm", BGM_SR, 0.5, True),
    "day_bgm": (day_bgm, "bgm", BGM_SR, 0.55, True),
    "night_ambience": (night_ambience, "bgm", BGM_SR, 0.5, True),
    "night_bgm": (night_bgm, "bgm", BGM_SR, 0.6, True),
    "forge_heat": (forge_heat, "sfx", SR, 0.85, False),
    "forge_overclock_ok": (forge_overclock_ok, "sfx", SR, 0.92, False),
    "forge_shatter": (forge_shatter, "sfx", SR, 0.95, False),
    "uv_defect_reveal": (uv_defect_reveal, "sfx", SR, 0.85, False),
    "cursor_tap": (cursor_tap, "sfx", SR, 0.5, False),               # 끝에 붙여야 앞 소리들의 시드가 그대로
    "coin_tally": (coin_tally, "sfx", SR, 0.8, False),
    "shop_door_bell": (shop_door_bell, "sfx", SR, 0.75, False),
    "guest_footsteps_out": (guest_footsteps_out, "sfx", SR, 0.8, False),
    "supply_low": (supply_low, "sfx", SR, 0.7, False),
    "forge_dud": (forge_dud, "sfx", SR, 0.8, False),
    "midboss_horn": (midboss_horn, "sfx", SR, 0.85, False),
}
