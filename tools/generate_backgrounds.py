#!/usr/bin/env python3
"""심야 던전 공방 타이틀·인트로 배경 생성기 → assets/backgrounds/title.png (1920x1080).

    python tools/generate_backgrounds.py           # 없을 때만 생성 (있는 PNG 는 덮어쓰지 않는다)
    python tools/generate_backgrounds.py --force   # 다시 그린다

장면: 달빛 아래 던전 입구(오른쪽 절벽의 붉은 보랏빛 관문) 앞, 창마다 불이 켜진 심야 전당포. 왼쪽은 메뉴가 놓이도록 어둡게 비운다.
Pillow 가 필요하다 (번짐·안개 합성). 없으면 아무것도 만들지 않고 끝나며, 게임은 코드로 그린 대체 배경을 쓴다.
직접 그린 그림으로 바꾸려면 같은 경로에 16:9 PNG 를 넣으면 된다 (게임이 화면에 맞춰 확대·이동한다).
"""

import math
import os
import random
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    Image = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 1920, 1080


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def paint(base, draw_fn, blur=0):
    """draw_fn(ImageDraw) 로 그린 투명 레이어를 (번진 뒤) 합성한다."""
    image = layer()
    draw_fn(ImageDraw.Draw(image))
    if blur > 0:
        image = image.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(image)


def vertical_gradient(stops):
    """stops: [(y 비율, (r, g, b)), ...] → W x H RGBA."""
    column = Image.new("RGB", (1, H))
    pixels = []
    for y in range(H):
        t = y / (H - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / max(t1 - t0, 1e-6)
                pixels.append(tuple(int(a + (b - a) * k) for a, b in zip(c0, c1)))
                break
    column.putdata(pixels)
    return column.resize((W, H)).convert("RGBA")


def ridge(rng, y_base, amplitude, step, x0=-40, x1=W + 40):
    points, x = [(x0, H)], x0
    while x <= x1:
        points.append((x, y_base - rng.uniform(0, amplitude) - amplitude * 0.5 * math.sin(x / 260.0)))
        x += rng.uniform(step * 0.6, step * 1.4)
    points.append((x1, H))
    return points


def sky(base, rng):
    def stars(d):
        for _ in range(420):
            x, y = rng.uniform(0, W), rng.uniform(0, H * 0.62)
            r = rng.choice((0.8, 1.0, 1.2, 1.8))
            d.ellipse((x - r, y - r, x + r, y + r), fill=(235, 230, 255, rng.randint(70, 220)))
    paint(base, stars)
    paint(base, lambda d: d.ellipse((1180, -160, 1940, 600), fill=(110, 100, 170, 70)), blur=110)
    paint(base, lambda d: d.ellipse((1400, 60, 1720, 380), fill=(200, 190, 220, 90)), blur=40)

    def moon(d):
        d.ellipse((1455, 115, 1665, 325), fill=(242, 234, 205, 255))
    paint(base, moon)

    def maria(d):
        for cx, cy, r in ((1525, 190, 30), (1600, 250, 38), (1570, 160, 16), (1515, 265, 18)):
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(205, 194, 168, 70))
    paint(base, maria, blur=14)

    def clouds(d):
        for cx, cy, rx, ry, a in ((1350, 300, 320, 34, 190), (1700, 360, 260, 28, 170), (880, 200, 380, 30, 120),
                                  (430, 120, 300, 24, 100), (1560, 250, 200, 16, 150)):
            d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(34, 24, 54, a))
    paint(base, clouds, blur=18)
    paint(base, lambda d: d.ellipse((1380, 278, 1720, 300), fill=(170, 160, 200, 90)), blur=6)


def mountains(base, rng):
    paint(base, lambda d: d.polygon(ridge(rng, 640, 120, 90), fill=(34, 25, 52, 255)), blur=2)
    paint(base, lambda d: d.polygon(ridge(rng, 720, 80, 70), fill=(21, 16, 34, 255)), blur=1)


def gate(base, rng):
    cliff = [(1360, H), (1380, 560), (1430, 470), (1470, 410), (1540, 360), (1620, 330), (1700, 300), (1790, 320),
             (1860, 280), (1920, 300), (1920, H)]
    paint(base, lambda d: d.polygon(cliff, fill=(18, 13, 26, 255)))
    paint(base, lambda d: d.line(cliff[1:-1], fill=(60, 48, 80, 200), width=3), blur=1)
    arch_outer = [(1540, 820), (1540, 560), (1570, 500), (1620, 462), (1690, 448), (1760, 462), (1810, 500), (1840, 560),
                  (1840, 820)]
    arch_inner = [(1580, 820), (1580, 575), (1605, 528), (1645, 500), (1690, 492), (1735, 500), (1775, 528), (1800, 575),
                  (1800, 820)]
    paint(base, lambda d: d.polygon(arch_outer, fill=(52, 42, 66, 255)))
    paint(base, lambda d: d.polygon(arch_inner, fill=(10, 4, 14, 255)))
    paint(base, lambda d: d.ellipse((1560, 520, 1820, 860), fill=(170, 30, 90, 170)), blur=45)
    paint(base, lambda d: d.ellipse((1630, 600, 1750, 800), fill=(255, 110, 150, 150)), blur=30)
    paint(base, lambda d: d.ellipse((1660, 650, 1720, 760), fill=(255, 210, 230, 120)), blur=14)

    def runes(d):
        for i in range(9):
            angle = math.pi * (1.05 + 0.9 * i / 8)
            x, y = 1690 + math.cos(angle) * 170, 640 + math.sin(angle) * 190
            d.line((x - 7, y - 9, x + 3, y + 1, x - 5, y + 9), fill=(210, 130, 255, 230), width=3)
    paint(base, runes, blur=1)
    paint(base, runes, blur=6)
    for tx in (1515, 1865):
        paint(base, lambda d, tx=tx: d.ellipse((tx - 60, 610, tx + 60, 730), fill=(255, 140, 50, 110)), blur=26)
        paint(base, lambda d, tx=tx: (d.rectangle((tx - 4, 668, tx + 4, 720), fill=(40, 28, 24, 255)),
                                      d.ellipse((tx - 9, 646, tx + 9, 672), fill=(255, 200, 110, 255))))


def ground(base, rng):
    paint(base, lambda d: d.rectangle((0, 780, W, H), fill=(13, 10, 17, 255)), blur=3)
    path = [(700, H), (1080, 840), (1560, 800), (1700, 812), (1440, 880), (1260, H)]
    paint(base, lambda d: d.polygon(path, fill=(34, 28, 38, 255)), blur=4)

    def cobbles(d):
        for _ in range(260):
            x, y = rng.uniform(760, 1600), rng.uniform(820, H)
            r = rng.uniform(4, 11) * (0.6 + (y - 800) / 400)
            d.ellipse((x - r * 1.6, y - r, x + r * 1.6, y + r), outline=(20, 16, 24, 180), width=2)
    paint(base, cobbles, blur=1)


def workshop(base, rng):
    paint(base, lambda d: d.ellipse((880, 380, 1440, 900), fill=(255, 150, 60, 45)), blur=90)
    paint(base, lambda d: (d.rectangle((1240, 230, 1292, 380), fill=(40, 34, 42, 255)),
                           d.rectangle((1232, 222, 1300, 238), fill=(52, 44, 54, 255))))
    paint(base, lambda d: d.rectangle((930, 560, 1330, 870), fill=(44, 38, 46, 255)))

    def stones(d):
        for row, y in enumerate(range(570, 860, 28)):
            offset = 0 if row % 2 == 0 else 34
            for x in range(930 + offset, 1330, 68):
                d.rectangle((x, y, x + 64, y + 24), outline=(26, 22, 28, 255), width=2)
    paint(base, stones)
    paint(base, lambda d: d.rectangle((900, 400, 1360, 582), fill=(64, 52, 54, 255)))

    def timber(d):
        beam = (34, 22, 18, 255)
        for x in (900, 1015, 1130, 1245, 1350):
            d.rectangle((x, 400, x + 12, 582), fill=beam)
        d.rectangle((900, 400, 1362, 412), fill=beam)
        d.rectangle((900, 570, 1362, 584), fill=beam)
        for x0, x1 in ((912, 1015), (1142, 1245)):
            d.line((x0, 412, x1, 570), fill=beam, width=9)
            d.line((x1, 412, x0, 570), fill=beam, width=9)
    paint(base, timber)
    roof = [(860, 418), (1130, 236), (1400, 418)]
    paint(base, lambda d: d.polygon(roof, fill=(26, 19, 28, 255)))
    paint(base, lambda d: d.line((860, 418, 1130, 236, 1400, 418), fill=(70, 58, 80, 255), width=6))
    paint(base, lambda d: (d.polygon([(1082, 330), (1130, 290), (1178, 330), (1178, 380), (1082, 380)], fill=(30, 22, 30, 255)),
                           d.rectangle((1110, 330, 1150, 372), fill=(255, 190, 110, 255))))
    windows = [(978, 446, 1048, 528), (1212, 446, 1282, 528), (958, 640, 1120, 770)]
    for box in windows:
        x0, y0, x1, y1 = box
        paint(base, lambda d, b=box: d.ellipse((b[0] - 50, b[1] - 40, b[2] + 50, b[3] + 40), fill=(255, 160, 70, 120)), blur=30)
        paint(base, lambda d, b=box: d.rectangle(b, fill=(255, 178, 92, 255)))
        paint(base, lambda d, b=box: d.rectangle((b[0] + 6, b[1] + 6, b[2] - 6, b[1] + (b[3] - b[1]) * 0.5),
                                                 fill=(255, 225, 160, 160)), blur=6)
        paint(base, lambda d, b=box: (d.line(((b[0] + b[2]) / 2, b[1], (b[0] + b[2]) / 2, b[3]), fill=(40, 26, 20, 255), width=6),
                                      d.line((b[0], (b[1] + b[3]) / 2, b[2], (b[1] + b[3]) / 2), fill=(40, 26, 20, 255), width=6),
                                      d.rectangle(b, outline=(40, 26, 20, 255), width=6)))

    def relics(d):     # 진열창 안 유물 실루엣
        for x, h in ((978, 40), (1004, 28), (1030, 52), (1062, 34), (1090, 46)):
            d.rectangle((x, 760 - h, x + 16, 760), fill=(70, 36, 22, 220))
        d.ellipse((1026, 690, 1046, 710), fill=(70, 36, 22, 220))
    paint(base, relics)
    paint(base, lambda d: d.polygon([(1168, 650), (1262, 650), (1262, 862), (1168, 862)], fill=(24, 16, 14, 255)))
    paint(base, lambda d: d.polygon([(1168, 650), (1206, 662), (1206, 852), (1168, 862)], fill=(255, 176, 90, 255)))
    paint(base, lambda d: d.polygon([(1168, 862), (1206, 852), (1300, 960), (1150, 990)], fill=(255, 160, 70, 90)), blur=16)

    def sign(d):
        d.line((1330, 598, 1460, 598), fill=(30, 22, 18, 255), width=8)
        d.line((1350, 598, 1330, 640), fill=(30, 22, 18, 255), width=6)
        d.line((1372, 598, 1372, 616), fill=(120, 110, 100, 255), width=3)
        d.line((1440, 598, 1440, 616), fill=(120, 110, 100, 255), width=3)
        d.rounded_rectangle((1352, 614, 1460, 690), radius=8, fill=(78, 50, 30, 255), outline=(200, 150, 60, 255), width=4)
        d.ellipse((1388, 628, 1424, 664), fill=(236, 214, 150, 255))
        d.ellipse((1400, 624, 1432, 656), fill=(78, 50, 30, 255))
        d.line((1392, 676, 1426, 642), fill=(200, 150, 60, 255), width=5)
    paint(base, sign)

    def smoke(d):
        for i in range(12):
            r = 24 + i * 9
            x, y = 1266 - i * 26 + rng.uniform(-10, 10), 210 - i * 22
            d.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=(90, 84, 104, max(10, 90 - i * 7)))
    paint(base, smoke, blur=14)


def foreground(base, rng):
    def tree(d):
        trunk = [(150, H), (190, 780), (230, 620), (250, 470), (282, 470), (276, 640), (300, 800), (330, H)]
        d.polygon(trunk, fill=(7, 5, 9, 255))
        for x0, y0, x1, y1, w in ((260, 520, 120, 360, 16), (262, 500, 420, 330, 14), (200, 690, 40, 600, 14),
                                  (180, 420, 90, 300, 9), (400, 370, 520, 300, 8), (140, 380, 60, 320, 7)):
            d.line((x0, y0, x1, y1), fill=(7, 5, 9, 255), width=w)
    paint(base, tree)

    def props(d):
        d.rectangle((560, 900, 700, 1010), fill=(9, 7, 11, 255))
        d.rectangle((640, 860, 740, 950), fill=(9, 7, 11, 255))
        d.ellipse((760, 900, 850, 1040), fill=(9, 7, 11, 255))
        d.rectangle((0, 1010, W, H), fill=(6, 5, 8, 255))
    paint(base, props, blur=1)

    def fog(d):
        for _ in range(18):
            cx, cy = rng.uniform(-100, W + 100), rng.uniform(760, 960)
            rx, ry = rng.uniform(220, 520), rng.uniform(26, 60)
            d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(140, 128, 170, rng.randint(18, 40)))
    paint(base, fog, blur=36)

    def embers(d):
        for _ in range(40):
            x, y = rng.uniform(1100, 1450), rng.uniform(120, 560)
            r = rng.uniform(1, 2.4)
            d.ellipse((x - r, y - r, x + r, y + r), fill=(255, rng.randint(120, 200), 60, rng.randint(120, 230)))
    paint(base, embers)


def vignette(base):
    radial = Image.radial_gradient("L").resize((int(W * 1.25), int(H * 1.45)))
    left, top = (radial.width - W) // 2, (radial.height - H) // 2
    mask = radial.crop((left, top, left + W, top + H)).point(lambda v: int(min(255, (v / 255.0) ** 1.7 * 235)))
    shade = Image.new("RGBA", (W, H), (3, 2, 6, 255))
    shade.putalpha(mask)
    base.alpha_composite(shade)
    column = Image.new("L", (W, 1))     # 왼쪽 메뉴 자리를 어둡게
    column.putdata([int(max(0, 1 - x / 820.0) ** 1.4 * 170) for x in range(W)])
    left_shade = Image.new("RGBA", (W, H), (4, 3, 8, 255))
    left_shade.putalpha(column.resize((W, H)))
    base.alpha_composite(left_shade)


def title_scene():
    rng = random.Random(20261119)
    base = vertical_gradient([(0.0, (7, 6, 18)), (0.45, (22, 15, 40)), (0.68, (46, 24, 52)), (1.0, (12, 9, 16))])
    for step in (sky, mountains, gate, ground, workshop, foreground):
        step(base, rng)
    vignette(base)
    return base.convert("RGB")


def main(argv):
    if Image is None:
        print("Pillow is not installed - skipping (the game draws a built-in fallback background)")
        return
    out_dir = os.path.join(ROOT, "assets", "backgrounds")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "title.png")
    if os.path.exists(path) and "--force" not in argv:
        print("keep   assets/backgrounds/title.png (already exists - not overwritten, use --force)")
        return
    title_scene().save(path, optimize=True)
    print("create assets/backgrounds/title.png (%dx%d)" % (W, H))


if __name__ == "__main__":
    main(sys.argv[1:])
