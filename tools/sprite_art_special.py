"""업적 해금 특수 유물 8종 아이콘 도안 (tools/generate_sprites.py 가 sprite_art.ITEM_ART 와 합쳐 쓴다).

ui/ItemShapesSpecial.lua 의 절차적 도형을 같은 정규화 좌표로 옮긴 것이다. 도안 함수: fn(canvas, primary, accent).
"""

from sprite_art import METAL, DARK, SHINE, GOLD


def hammer(c, primary, accent):
    c.rect(-0.04, -0.12, 0.08, 0.56, DARK)
    c.rect(-0.34, -0.42, 0.68, 0.26, primary, 0.04)
    c.circle(0, 0.45, 0.05, primary)
    c.rect(-0.34, -0.42, 0.1, 0.26, accent)
    c.rect(0.24, -0.42, 0.1, 0.26, accent)
    c.circle(0, -0.29, 0.07, GOLD)


def goblet(c, primary, accent):
    c.poly(primary, -0.3, -0.36, 0.3, -0.36, 0.18, 0.04, -0.18, 0.04)
    c.rect(-0.04, 0.04, 0.08, 0.24, primary)
    c.poly(primary, -0.22, 0.42, 0.22, 0.42, 0.1, 0.28, -0.1, 0.28)
    c.poly(accent, -0.26, -0.32, 0.26, -0.32, 0.22, -0.2, -0.22, -0.2)
    c.circle(0, -0.08, 0.09, GOLD)
    c.circle(0.04, -0.1, 0.08, primary)


def crown(c, primary, accent):
    c.poly(primary, -0.36, 0.06, -0.3, -0.34, -0.16, 0.06)
    c.poly(primary, -0.12, 0.06, 0, -0.44, 0.12, 0.06)
    c.poly(primary, 0.16, 0.06, 0.3, -0.34, 0.36, 0.06)
    c.rect(-0.36, 0.04, 0.72, 0.22, primary, 0.03)
    c.circle(-0.22, 0.15, 0.05, accent)
    c.circle(0, 0.15, 0.06, accent)
    c.circle(0.22, 0.15, 0.05, accent)
    c.circle(0, -0.4, 0.05, accent)


def heartstone(c, primary, accent):
    c.poly(DARK, 0, -0.44, 0.34, -0.18, 0.3, 0.22, 0, 0.44, -0.3, 0.22, -0.34, -0.18)
    c.circle(-0.1, -0.06, 0.14, primary)
    c.circle(0.1, -0.06, 0.14, primary)
    c.poly(primary, -0.23, 0.0, 0.23, 0.0, 0, 0.28)
    c.circle(0, 0.0, 0.07, accent)


def sack(c, primary, accent):
    c.circle(0, 0.12, 0.3, primary)
    c.poly(primary, -0.12, -0.2, 0.12, -0.2, 0.18, -0.06, -0.18, -0.06)
    c.poly(primary, -0.2, -0.36, 0.2, -0.36, 0.12, -0.2, -0.12, -0.2)
    c.rect(-0.16, -0.22, 0.32, 0.05, accent)
    c.circle(-0.32, 0.36, 0.08, GOLD)
    c.circle(0.3, 0.38, 0.07, GOLD)
    c.circle(0, 0.14, 0.09, GOLD)


def tome(c, primary, accent):
    c.rect(-0.3, -0.4, 0.6, 0.8, primary, 0.04)
    c.rect(-0.3, -0.4, 0.1, 0.8, DARK)
    c.rect(0.26, -0.36, 0.06, 0.72, METAL)
    c.circle(0.04, -0.06, 0.13, accent)
    c.rect(-0.02, 0.04, 0.12, 0.08, accent)
    c.circle(-0.01, -0.07, 0.035, DARK)
    c.circle(0.09, -0.07, 0.035, DARK)


def prism(c, primary, accent):
    c.poly(primary, 0, -0.44, 0.38, 0.32, -0.38, 0.32)
    c.poly(accent, 0, -0.44, 0.38, 0.32, 0.0, 0.1)
    c.rect(-0.3, 0.32, 0.6, 0.1, DARK)
    c.poly(SHINE, -0.12, -0.1, -0.04, -0.26, -0.02, -0.04)


def ledger(c, primary, accent):
    c.rect(-0.32, -0.38, 0.64, 0.76, primary, 0.03)
    c.poly(GOLD, -0.32, -0.38, -0.18, -0.38, -0.32, -0.24)
    c.poly(GOLD, 0.32, -0.38, 0.32, -0.24, 0.18, -0.38)
    c.poly(GOLD, -0.32, 0.38, -0.32, 0.24, -0.18, 0.38)
    c.poly(GOLD, 0.32, 0.38, 0.18, 0.38, 0.32, 0.24)
    c.rect(0.26, -0.06, 0.1, 0.12, GOLD)
    c.circle(0, 0, 0.13, accent)
    c.circle(0, 0, 0.07, GOLD)


ITEM_ART = {
    "hammer": hammer, "goblet": goblet, "crown": crown, "heartstone": heartstone,
    "sack": sack, "tome": tome, "prism": prism, "ledger": ledger,
}
