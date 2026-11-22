"""유물 24종 아이콘 도안 (tools/generate_sprites.py 가 사용).

ui/ItemShapes.lua · ui/ItemShapesExtra.lua 의 절차적 도형을 같은 정규화 좌표로 옮긴 것이다 — 스프라이트가 없을 때의
폴백 도형과 실루엣이 같아야 오염 얼룩·결함 표식 위치가 어긋나지 않는다. 입체감·외곽선은 sprite_canvas.stylize 가 더한다.
도안 함수: fn(canvas, primary, accent). 키는 data/items.lua 의 shape 이름.
"""

import math

METAL = (0.82, 0.84, 0.88)
DARK = (0.22, 0.18, 0.16)
SHINE = (1.0, 1.0, 1.0, 0.55)
GOLD = (1.0, 0.82, 0.3)
PI = math.pi


def sword(c, primary, accent):
    c.poly(METAL, 0, -0.47, 0.075, -0.36, 0.075, 0.16, -0.075, 0.16, -0.075, -0.36)
    c.poly(accent, 0, -0.40, 0.025, -0.33, 0.025, 0.12, -0.025, 0.12, -0.025, -0.33)
    c.rect(-0.22, 0.16, 0.44, 0.07, primary, 0.02)
    c.rect(-0.04, 0.23, 0.08, 0.16, DARK)
    c.circle(0, 0.43, 0.055, primary)


def dagger(c, primary, accent):
    c.push(0, 0.06, 0.78)
    sword(c, primary, accent)
    c.pop()


def orb(c, primary, accent):
    c.poly(DARK, -0.2, 0.45, 0.2, 0.45, 0.13, 0.28, -0.13, 0.28)
    c.circle(0, -0.04, 0.33, primary)
    c.circle(0, -0.04, 0.2, accent)
    c.circle(-0.11, -0.16, 0.07, SHINE)


def crystal(c, primary, accent):
    c.poly(primary, 0, -0.47, 0.24, -0.2, 0.24, 0.2, 0, 0.47, -0.24, 0.2, -0.24, -0.2)
    c.poly(accent, 0, -0.47, 0.24, -0.2, 0, -0.05, -0.24, -0.2)
    c.poly(DARK, 0, -0.05, 0.24, 0.2, 0, 0.47)
    c.poly(SHINE, -0.16, -0.18, -0.06, -0.3, -0.04, -0.12)


def chalice(c, primary, accent):
    c.poly(primary, -0.32, -0.38, 0.32, -0.38, 0.2, 0.02, -0.2, 0.02)
    c.rect(-0.045, 0.02, 0.09, 0.24, primary)
    c.poly(primary, -0.24, 0.42, 0.24, 0.42, 0.12, 0.26, -0.12, 0.26)
    c.rect(-0.32, -0.38, 0.64, 0.07, accent)
    c.circle(0, -0.17, 0.065, accent)
    c.poly(SHINE, -0.26, -0.28, -0.18, -0.28, -0.14, -0.04, -0.18, -0.04)


def crossbow(c, primary, accent):
    c.rect(-0.055, -0.3, 0.11, 0.74, DARK, 0.03)
    c.arc(0, 0.05, 0.42, PI * 1.15, PI * 1.85, 0.07, primary, 24)
    c.line([(-0.344, -0.19), (0, 0.0), (0.344, -0.19)], 0.018, METAL)
    c.rect(-0.016, -0.38, 0.032, 0.4, accent)
    c.poly(accent, 0, -0.48, 0.055, -0.38, -0.055, -0.38)


def fork(c, primary, accent):
    c.rect(-0.17, -0.44, 0.08, 0.42, METAL)
    c.rect(0.09, -0.44, 0.08, 0.42, METAL)
    c.rect(-0.17, -0.06, 0.34, 0.08, METAL)
    c.rect(-0.04, 0.02, 0.08, 0.3, METAL)
    c.circle(0, 0.38, 0.075, primary)
    c.arc(0.17, -0.25, 0.12, -0.6, 0.6, 0.03, accent, 10)
    c.arc(0.17, -0.25, 0.2, -0.6, 0.6, 0.03, accent, 12)


def crest(c, primary, accent):
    c.poly(primary, -0.34, -0.4, 0.34, -0.4, 0.34, 0.04, 0, 0.46, -0.34, 0.04)
    c.poly(DARK, -0.26, -0.32, 0.26, -0.32, 0.26, 0.02, 0, 0.36, -0.26, 0.02)
    c.rect(-0.05, -0.26, 0.1, 0.5, accent)
    c.rect(-0.18, -0.12, 0.36, 0.1, accent)


def pouch(c, primary, accent):
    c.circle(0, 0.12, 0.32, primary)
    c.poly(primary, -0.13, -0.18, 0.13, -0.18, 0.2, -0.34, -0.2, -0.34)
    c.circle(0.13, -0.38, 0.075, accent)
    c.circle(-0.06, -0.41, 0.075, accent)
    c.rect(-0.17, -0.23, 0.34, 0.07, accent, 0.02)
    c.rect(-0.03, 0.0, 0.06, 0.24, DARK)
    c.rect(-0.09, 0.05, 0.18, 0.045, DARK)


def tablet(c, primary, accent):
    c.rect(-0.3, -0.42, 0.6, 0.84, primary, 0.08)
    c.rect(-0.24, -0.36, 0.48, 0.72, DARK, 0.05)
    c.line([(-0.15, -0.26), (-0.05, -0.16), (-0.15, -0.06)], 0.035, accent)
    c.line([(0.04, -0.26), (0.15, -0.26), (0.09, -0.1)], 0.035, accent)
    c.line([(-0.13, 0.07), (0.13, 0.07)], 0.035, accent)
    c.line([(0, 0.0), (0, 0.27)], 0.035, accent)
    c.line([(-0.1, 0.2), (0.1, 0.28)], 0.035, accent)


def musket(c, primary, accent):
    c.poly(primary, -0.42, 0.18, -0.12, 0.06, -0.06, 0.2, -0.36, 0.34)
    c.poly(METAL, -0.14, 0.04, 0.44, -0.3, 0.48, -0.22, -0.08, 0.14)
    c.circle(0.46, -0.27, 0.06, accent)
    c.rect(-0.16, 0.08, 0.1, 0.12, DARK)


def brazier(c, primary, accent):
    c.poly(primary, -0.34, -0.06, 0.34, -0.06, 0.24, 0.22, -0.24, 0.22)
    c.rect(-0.05, 0.22, 0.1, 0.14, primary)
    c.poly(primary, -0.22, 0.44, 0.22, 0.44, 0.1, 0.34, -0.1, 0.34)
    c.poly(accent, -0.22, -0.06, -0.1, -0.4, 0.0, -0.06)
    c.poly(accent, -0.04, -0.06, 0.08, -0.46, 0.2, -0.06)
    c.poly(GOLD, -0.08, -0.06, 0.02, -0.26, 0.12, -0.06)


def feather(c, primary, accent):
    c.poly(primary, 0.0, -0.46, 0.2, -0.2, 0.14, 0.18, -0.02, 0.32, -0.14, 0.12, -0.16, -0.22)
    c.poly(accent, 0.0, -0.3, 0.1, -0.12, 0.04, 0.12, -0.08, -0.1)
    c.line([(0.02, -0.4), (-0.04, 0.46)], 0.025, METAL)


def core(c, primary, accent):
    c.poly(DARK, -0.3, -0.1, 0.0, -0.4, 0.3, -0.1, 0.3, 0.2, 0.0, 0.42, -0.3, 0.2)
    c.circle(0, 0.03, 0.26, primary)
    c.circle(0, 0.03, 0.15, accent)
    c.circle(-0.05, -0.03, 0.06, GOLD)


def rod(c, primary, accent):
    c.rect(-0.035, -0.28, 0.07, 0.72, METAL)
    c.poly(primary, 0, -0.48, 0.09, -0.3, -0.09, -0.3)
    c.rect(-0.12, 0.36, 0.24, 0.08, primary, 0.02)
    c.line([(-0.18, -0.36), (-0.1, -0.24), (-0.2, -0.16), (-0.12, -0.04)], 0.03, accent)
    c.line([(0.18, -0.36), (0.1, -0.24), (0.2, -0.16), (0.12, -0.04)], 0.03, accent)


def coil(c, primary, accent):
    c.rect(-0.06, -0.44, 0.12, 0.88, DARK, 0.03)
    for i in range(5):
        c.rect(-0.26, -0.36 + i * 0.16, 0.52, 0.08, primary, 0.04)
    c.circle(0, -0.44, 0.07, accent)
    c.circle(0, 0.44, 0.07, accent)


def fins(c, primary, accent):
    c.rect(-0.36, 0.22, 0.72, 0.14, primary, 0.03)
    for i in range(5):
        c.rect(-0.32 + i * 0.15, -0.38, 0.08, 0.6, primary)
    c.rect(-0.36, -0.06, 0.72, 0.05, accent)
    c.rect(-0.3, -0.36, 0.03, 0.3, SHINE)


def idol(c, primary, accent):
    c.poly(primary, -0.2, 0.44, 0.2, 0.44, 0.16, -0.06, -0.16, -0.06)
    c.circle(0, -0.22, 0.2, primary)
    c.circle(-0.07, -0.24, 0.045, accent)
    c.circle(0.07, -0.24, 0.045, accent)
    c.poly(accent, -0.08, 0.1, 0.08, 0.1, 0, 0.26)
    c.rect(-0.28, 0.38, 0.56, 0.08, DARK, 0.02)


def scythe(c, primary, accent):
    c.poly(DARK, -0.06, 0.46, 0.0, 0.46, 0.14, -0.4, 0.08, -0.4)
    c.poly(METAL, 0.08, -0.44, 0.14, -0.36, -0.2, -0.2, -0.36, -0.12)
    c.poly(accent, -0.2, -0.22, -0.08, -0.28, -0.3, -0.14)
    c.circle(0.05, 0.1, 0.04, accent)


def lantern(c, primary, accent):
    c.rect(-0.2, -0.3, 0.4, 0.06, DARK)
    c.rect(-0.22, 0.32, 0.44, 0.08, DARK)
    c.rect(-0.18, -0.24, 0.36, 0.56, primary, 0.04)
    c.circle(0, 0.06, 0.12, accent)
    c.circle(0, 0.06, 0.06, SHINE)
    c.arc(0, -0.32, 0.12, PI, PI * 2, 0.03, METAL, 12)


def scroll(c, primary, accent):
    c.rect(-0.28, -0.32, 0.56, 0.64, primary)
    c.rect(-0.34, -0.4, 0.68, 0.1, DARK, 0.05)
    c.rect(-0.34, 0.3, 0.68, 0.1, DARK, 0.05)
    c.line([(-0.18, -0.18), (0.18, -0.18)], 0.03, accent)
    c.line([(-0.18, -0.06), (0.12, -0.06)], 0.03, accent)
    c.circle(0.1, 0.14, 0.08, accent)


def gauntlet(c, primary, accent):
    c.poly(primary, -0.24, 0.0, 0.24, 0.0, 0.2, 0.3, -0.2, 0.3)
    c.rect(-0.18, 0.3, 0.36, 0.16, primary, 0.03)
    for i in range(4):
        c.rect(-0.22 + i * 0.115, -0.38, 0.09, 0.4, primary, 0.04)
    c.rect(-0.2, 0.34, 0.4, 0.04, accent)
    c.circle(0, 0.14, 0.06, SHINE)


def scale(c, primary, accent):
    c.rect(-0.03, -0.38, 0.06, 0.74, primary)
    c.rect(-0.36, -0.3, 0.72, 0.05, primary)
    c.poly(primary, -0.16, 0.44, 0.16, 0.44, 0.06, 0.34, -0.06, 0.34)
    c.poly(accent, -0.44, 0.02, -0.2, 0.02, -0.26, 0.1, -0.38, 0.1)
    c.poly(accent, 0.2, 0.02, 0.44, 0.02, 0.38, 0.1, 0.26, 0.1)
    for ax, bx in ((-0.34, -0.42), (-0.34, -0.22), (0.34, 0.22), (0.34, 0.42)):
        c.line([(ax, -0.26), (bx, 0.02)], 0.015, METAL)


def golem(c, primary, accent):
    c.rect(-0.22, -0.12, 0.44, 0.42, primary, 0.06)
    c.rect(-0.14, -0.38, 0.28, 0.24, primary, 0.05)
    c.rect(-0.36, -0.08, 0.12, 0.3, primary, 0.04)
    c.rect(0.24, -0.08, 0.12, 0.3, primary, 0.04)
    c.rect(-0.18, 0.3, 0.13, 0.16, primary)
    c.rect(0.05, 0.3, 0.13, 0.16, primary)
    c.circle(0, 0.08, 0.1, accent)
    c.circle(-0.06, -0.27, 0.03, accent)
    c.circle(0.06, -0.27, 0.03, accent)


ITEM_ART = {
    "sword": sword, "dagger": dagger, "orb": orb, "crystal": crystal, "chalice": chalice, "crossbow": crossbow,
    "fork": fork, "crest": crest, "pouch": pouch, "tablet": tablet, "musket": musket, "brazier": brazier,
    "feather": feather, "core": core, "rod": rod, "coil": coil, "fins": fins, "idol": idol, "scythe": scythe,
    "lantern": lantern, "scroll": scroll, "gauntlet": gauntlet, "scale": scale, "golem": golem,
}
