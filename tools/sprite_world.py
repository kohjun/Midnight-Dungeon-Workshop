"""몬스터 스프라이트와 작업대 텍스처 도안 (tools/generate_sprites.py 가 사용).

몬스터: fn(canvas, color) — color 는 data/enemies.lua 의 몬스터 색. 방벽이 왼쪽에 있으므로 모두 왼쪽을 본다.
텍스처: fn(size, rng) → RGBA bytearray. 가로·세로로 이어 붙여도 이음매가 없는 타일이다 (128px 주기 함수만 사용).
"""

import math

WHITE = (0.97, 0.97, 0.95)
PUPIL = (0.10, 0.05, 0.08)
BONE = (0.88, 0.83, 0.70)
WOOD = (0.45, 0.30, 0.18)
IRON = (0.72, 0.74, 0.80)


def tint(color, factor):
    return tuple(max(0.0, min(1.0, v * factor)) for v in color[:3])


def eye(c, x, y, r, iris=PUPIL):
    c.circle(x, y, r, WHITE)
    c.circle(x - r * 0.35, y + r * 0.1, r * 0.5, iris)


def slime(c, color):
    c.ellipse(0, 0.14, 0.43, 0.31, color)
    c.ellipse(-0.02, -0.02, 0.3, 0.27, color)
    c.ellipse(0, 0.33, 0.4, 0.1, tint(color, 0.7))
    c.ellipse(-0.15, -0.13, 0.1, 0.06, (1, 1, 1, 0.5))
    eye(c, -0.2, 0.06, 0.08)
    eye(c, 0.06, 0.06, 0.08)
    c.line([(-0.17, 0.25), (-0.09, 0.29), (0.0, 0.25)], 0.022, PUPIL)


def goblin(c, color):
    cloth = (0.36, 0.24, 0.17)
    c.poly(cloth, -0.24, 0.46, 0.24, 0.46, 0.15, 0.04, -0.15, 0.04)
    c.rect(-0.2, 0.2, 0.4, 0.06, tint(cloth, 0.6))
    c.poly(color, -0.18, -0.24, -0.5, -0.38, -0.2, -0.02)          # 귀
    c.poly(color, 0.18, -0.24, 0.5, -0.38, 0.2, -0.02)
    c.circle(0, -0.14, 0.24, color)
    c.poly(tint(color, 0.75), -0.1, -0.12, -0.26, -0.05, -0.1, -0.02)   # 코
    eye(c, -0.12, -0.2, 0.06, (0.75, 0.15, 0.1))
    eye(c, 0.07, -0.2, 0.06, (0.75, 0.15, 0.1))
    c.line([(-0.14, 0.02), (-0.04, 0.05), (0.06, 0.02)], 0.02, PUPIL)
    c.line([(-0.3, 0.3), (-0.45, 0.0)], 0.045, IRON)                # 단검
    c.circle(-0.29, 0.3, 0.065, color)
    c.circle(0.27, 0.26, 0.065, color)


def ogre(c, color):
    c.rect(-0.22, 0.3, 0.17, 0.17, tint(color, 0.8), 0.04)         # 다리
    c.rect(0.05, 0.3, 0.17, 0.17, tint(color, 0.8), 0.04)
    c.rect(-0.34, -0.14, 0.68, 0.56, color, 0.16)
    c.ellipse(0, 0.2, 0.22, 0.18, tint(color, 1.2))
    c.rect(-0.36, 0.24, 0.72, 0.07, (0.3, 0.2, 0.14))
    c.circle(-0.04, -0.28, 0.18, color)
    eye(c, -0.12, -0.32, 0.045)
    eye(c, 0.03, -0.32, 0.045)
    c.poly(WHITE, -0.15, -0.2, -0.11, -0.2, -0.13, -0.28)           # 엄니
    c.poly(WHITE, 0.01, -0.2, 0.05, -0.2, 0.03, -0.28)
    c.line([(-0.36, 0.14), (-0.46, -0.36)], 0.09, WOOD)             # 몽둥이
    c.circle(-0.465, -0.38, 0.085, tint(WOOD, 0.8))
    c.circle(-0.35, 0.14, 0.08, color)
    c.circle(0.35, 0.1, 0.08, color)


def shield_bearer(c, color):
    """중장갑 방패병: 투구 쓴 병사 + 앞을 가린 커다란 탑 방패."""
    c.rect(-0.05, 0.28, 0.13, 0.18, tint(color, 0.6), 0.03)
    c.rect(0.14, 0.28, 0.13, 0.18, tint(color, 0.6), 0.03)
    c.rect(-0.06, -0.12, 0.38, 0.44, color, 0.08)
    c.circle(0.13, -0.24, 0.17, tint(color, 1.1))
    c.rect(-0.02, -0.28, 0.3, 0.06, tint(color, 0.55))
    c.circle(0.06, -0.24, 0.035, (0.9, 0.3, 0.2))
    c.poly(IRON, -0.44, -0.36, -0.06, -0.42, -0.04, 0.4, -0.42, 0.32)
    c.poly(tint(IRON, 0.7), -0.38, -0.3, -0.1, -0.34, -0.09, 0.32, -0.37, 0.26)
    c.line([(-0.24, -0.3), (-0.24, 0.3)], 0.04, tint(IRON, 1.15))
    c.circle(-0.24, 0.0, 0.06, (0.7, 0.55, 0.25))


def shadow_assassin(c, color):
    """그림자 암살자: 몸을 숙인 두건 실루엣 + 단검 두 자루 + 보라 눈."""
    c.poly(tint(color, 0.7), 0.05, -0.05, 0.42, 0.1, 0.3, 0.42, -0.1, 0.4)
    c.poly(color, -0.32, -0.12, 0.2, -0.28, 0.28, 0.18, -0.12, 0.3)
    c.poly(tint(color, 1.15), -0.42, -0.2, -0.12, -0.42, 0.02, -0.12, -0.3, 0.02)
    c.circle(-0.22, -0.16, 0.035, (0.78, 0.6, 1.0))
    c.circle(-0.12, -0.18, 0.035, (0.78, 0.6, 1.0))
    c.line([(-0.2, 0.12), (-0.48, 0.02)], 0.035, IRON)
    c.line([(0.08, 0.22), (-0.24, 0.32)], 0.035, IRON)
    c.line([(0.2, -0.26), (0.46, -0.4)], 0.05, tint(color, 0.8))


def skeleton(c, color):
    """해골 병사: 뼈 골격 + 녹슨 칼."""
    c.circle(-0.02, -0.28, 0.15, color)
    c.circle(-0.08, -0.3, 0.04, PUPIL)
    c.circle(0.04, -0.3, 0.04, PUPIL)
    c.rect(-0.08, -0.17, 0.12, 0.05, color)
    c.line([(0.0, -0.12), (0.0, 0.18)], 0.05, color)
    for y in (-0.06, 0.02, 0.1):
        c.line([(-0.12, y), (0.12, y)], 0.035, color)
    c.line([(0.0, 0.18), (-0.12, 0.44)], 0.045, color)
    c.line([(0.0, 0.18), (0.12, 0.44)], 0.045, color)
    c.line([(-0.12, -0.08), (-0.26, 0.12)], 0.04, color)
    c.line([(0.12, -0.08), (0.28, 0.06)], 0.04, color)
    c.line([(-0.26, 0.12), (-0.4, -0.2)], 0.05, tint(IRON, 0.7))


def gatekeeper_golem(c, color):
    """던전 문지기 골렘: 쌓아 올린 바위 몸체 + 푸른 룬 눈과 가슴 룬."""
    c.rect(-0.3, 0.26, 0.2, 0.2, tint(color, 0.7), 0.05)
    c.rect(0.1, 0.26, 0.2, 0.2, tint(color, 0.7), 0.05)
    c.rect(-0.32, -0.22, 0.64, 0.52, color, 0.1)
    c.rect(-0.48, -0.16, 0.16, 0.44, tint(color, 0.85), 0.06)
    c.rect(0.32, -0.16, 0.16, 0.44, tint(color, 0.85), 0.06)
    c.rect(-0.16, -0.44, 0.32, 0.24, tint(color, 1.1), 0.06)
    c.circle(-0.07, -0.33, 0.035, (0.5, 0.9, 1.0))
    c.circle(0.07, -0.33, 0.035, (0.5, 0.9, 1.0))
    c.line([(-0.1, -0.08), (0.0, 0.08), (0.1, -0.08)], 0.04, (0.5, 0.9, 1.0))
    c.line([(-0.24, -0.1), (-0.14, 0.2)], 0.025, tint(color, 0.55))


def greed_raider(c, color):
    """탐욕의 고블린 약탈자: 금화 자루를 둘러멘 고블린 우두머리."""
    c.circle(0.22, -0.12, 0.24, (0.5, 0.34, 0.18))
    c.circle(0.26, -0.36, 0.06, (1.0, 0.84, 0.3))
    c.circle(0.14, -0.33, 0.05, (1.0, 0.84, 0.3))
    c.poly(color, -0.3, 0.44, 0.12, 0.44, 0.02, -0.1, -0.22, -0.1)
    c.circle(-0.12, -0.22, 0.17, tint(color, 1.08))
    c.poly(tint(color, 1.08), -0.26, -0.26, -0.46, -0.36, -0.24, -0.16)
    c.circle(-0.16, -0.24, 0.035, (0.95, 0.25, 0.2))
    c.circle(-0.06, -0.24, 0.035, (0.95, 0.25, 0.2))
    c.rect(-0.26, -0.42, 0.26, 0.08, (0.55, 0.12, 0.1), 0.03)
    c.line([(-0.26, 0.06), (-0.46, 0.26)], 0.05, WOOD)


def abyss_necromancer(c, color):
    """심연의 사령술사: 두건 로브 + 해골이 달린 지팡이 + 초록 영혼불."""
    c.poly(color, -0.28, 0.46, 0.3, 0.46, 0.14, -0.2, -0.12, -0.2)
    c.poly(tint(color, 1.2), -0.16, -0.18, 0.18, -0.18, 0.1, -0.46, -0.08, -0.46)
    c.circle(0.01, -0.26, 0.08, (0.05, 0.03, 0.05))
    c.circle(-0.02, -0.27, 0.025, (0.4, 1.0, 0.5))
    c.circle(0.05, -0.27, 0.025, (0.4, 1.0, 0.5))
    c.line([(-0.36, 0.46), (-0.36, -0.36)], 0.045, WOOD)
    c.circle(-0.36, -0.42, 0.08, BONE)
    c.circle(-0.38, -0.43, 0.02, PUPIL)
    c.circle(-0.33, -0.43, 0.02, PUPIL)
    c.ellipse(-0.36, -0.56, 0.06, 0.08, (0.4, 1.0, 0.5, 0.85))
    c.line([(0.1, 0.0), (0.34, 0.1)], 0.05, tint(color, 0.8))


def rift_lord(c, color):
    """차원의 균열 군주: 세 갈래 왕관 뿔과 가슴을 가른 보라 균열."""
    c.poly(color, -0.34, 0.46, 0.34, 0.46, 0.28, -0.18, -0.28, -0.18)
    for x in (-0.2, 0.0, 0.2):
        c.poly(tint(color, 1.15), x - 0.08, -0.18, x, -0.48 + abs(x) * 0.6, x + 0.08, -0.18)
    c.circle(-0.08, -0.06, 0.04, (1.0, 0.85, 1.0))
    c.circle(0.08, -0.06, 0.04, (1.0, 0.85, 1.0))
    c.line([(-0.04, 0.04), (0.06, 0.2), (-0.05, 0.32), (0.04, 0.44)], 0.05, (0.85, 0.6, 1.0))
    c.ellipse(0.0, 0.22, 0.12, 0.18, (0.7, 0.4, 1.0, 0.35))
    c.poly(tint(color, 0.7), -0.34, -0.1, -0.5, 0.1, -0.34, 0.2)
    c.poly(tint(color, 0.7), 0.34, -0.1, 0.5, 0.1, 0.34, 0.2)


MONSTER_ART = {
    "slime": slime, "goblin": goblin, "ogre": ogre,
    "shield_bearer": shield_bearer, "shadow_assassin": shadow_assassin, "skeleton": skeleton,
    "gatekeeper_golem": gatekeeper_golem, "greed_raider": greed_raider, "abyss_necromancer": abyss_necromancer,
    "rift_lord": rift_lord,
}


def _put(pixels, size, x, y, color, shade):
    i = (y * size + x) * 4
    for channel in range(3):
        pixels[i + channel] = max(0, min(255, int(color[channel] * shade * 255 + 0.5)))
    pixels[i + 3] = 255


def wood(size, rng):
    """가로 널빤지 4장: 결·옹이·이음매."""
    planks = ((0.30, 0.20, 0.12), (0.27, 0.18, 0.11), (0.33, 0.22, 0.13), (0.28, 0.19, 0.115))
    height = size // len(planks)
    pixels = bytearray(size * size * 4)
    for y in range(size):
        plank, within = y // height, y % height
        seam = (plank * 47 + 19) % size
        for x in range(size):
            u, v = x / size, within / height
            grain = math.sin(math.tau * (u * 3 + plank * 0.37) + 3.5 * math.sin(math.tau * (v + u * 2)))
            knot = math.exp(-(((x - (plank * 61 + 30) % size) / 9.0) ** 2 + ((within - height / 2) / 5.0) ** 2))
            shade = 1.0 + 0.11 * grain - 0.35 * knot + rng.uniform(-0.04, 0.04)
            if within < 2 or abs(x - seam) < 1:
                shade *= 0.42
            elif within == 2:
                shade *= 1.18
            _put(pixels, size, x, y, planks[plank], shade)
    return pixels


def stone(size, rng):
    """어긋나게 쌓은 석재 블록 2줄: 줄눈·모서리 음영·얼룩."""
    base = (0.20, 0.21, 0.26)
    mortar = (0.07, 0.07, 0.09)
    tones = (0.92, 1.07, 1.0, 0.86)
    half = size // 2
    pixels = bytearray(size * size * 4)
    for y in range(size):
        row, ly = y // half, y % half
        for x in range(size):
            shifted = (x + row * (half // 2)) % size
            lx = shifted % half
            blotch = math.sin(math.tau * (x / size * 2 + y / size)) * math.sin(math.tau * (y / size * 3 - x / size))
            speckle = rng.uniform(-0.06, 0.06)
            if lx < 3 or ly < 3:
                _put(pixels, size, x, y, mortar, 1.0 + speckle)
                continue
            shade = tones[row * 2 + shifted // half] * (1.0 + 0.07 * blotch + speckle)
            if lx < 6 or ly < 6:
                shade *= 1.16
            elif lx > half - 4 or ly > half - 4:
                shade *= 0.8
            _put(pixels, size, x, y, base, shade)
    return pixels


TEXTURE_ART = {"wood": wood, "stone": stone}
