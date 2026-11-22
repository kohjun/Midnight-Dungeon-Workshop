"""심야 던전 공방 오디오 합성 공용 도구 (tools/generate_audio.py · tools/audio_scenes.py 가 쓴다).

표준 라이브러리 math 만 사용한다. 필터·스윕·종소리·믹스·루프 교차 페이드·백색 소음.
"""

import math

SR = 44100
BGM_SR = 22050
TAU = math.pi * 2


def seconds(duration, rate=SR):
    return int(duration * rate)


def decay(t, rate):
    return math.exp(-t * rate)


def lowpass(samples, cutoff, rate=SR):
    """1차 저역 통과 필터."""
    alpha = 1.0 - math.exp(-TAU * cutoff / rate)
    out, y = [], 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff, rate=SR):
    low = lowpass(samples, cutoff, rate)
    return [x - l for x, l in zip(samples, low)]


def sweep(f0, f1, duration, rate=SR, shape=math.sin, curve=1.0):
    """f0 → f1 로 주파수가 변하는 파형 (위상 누적)."""
    out, phase, count = [], 0.0, seconds(duration, rate)
    for i in range(count):
        t = (i / count) ** curve
        phase += TAU * (f0 + (f1 - f0) * t) / rate
        out.append(shape(phase))
    return out


def bell(freq, duration, rate_of_decay, partials=((1.0, 1.0), (2.01, 0.45), (3.02, 0.2))):
    """배음이 살짝 어긋난 종소리."""
    out = []
    for i in range(seconds(duration)):
        t = i / SR
        out.append(sum(amp * math.sin(TAU * freq * mult * t) * decay(t, rate_of_decay * mult) for mult, amp in partials))
    return out


def mix(length, *layers):
    """(시작 시각, 샘플 목록, 음량) 레이어를 length 초 버퍼에 더한다."""
    out = [0.0] * seconds(length)
    for start, samples, gain in layers:
        offset = seconds(start)
        for i, value in enumerate(samples):
            if offset + i < len(out):
                out[offset + i] += value * gain
    return out


def shaped(samples, fn):
    """샘플마다 진폭 fn(진행률 0~1) 을 곱한다."""
    count = max(1, len(samples) - 1)
    return [value * fn(i / count) for i, value in enumerate(samples)]


def loop_crossfade(samples, overlap):
    """꼬리를 머리에 겹쳐 이음매 없는 루프로 만든다 (결과 길이 = len - overlap)."""
    body = samples[:len(samples) - overlap]
    for i in range(overlap):
        t = i / overlap
        body[i] = body[i] * t + samples[len(samples) - overlap + i] * (1.0 - t)
    return body


def white(rng, count):
    return [rng.uniform(-1.0, 1.0) for _ in range(count)]
