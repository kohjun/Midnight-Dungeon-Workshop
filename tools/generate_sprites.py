#!/usr/bin/env python3
"""심야 던전 공방 디자인 에셋 생성기: 원화가 없는 유물 아이콘 · 몬스터 + 작업대 나무/석재 텍스처 (128x128 PNG).

    python tools/generate_sprites.py            # assets/sprites/ 에 생성
    python tools/generate_sprites.py --no-pil   # Pillow 가 있어도 표준 라이브러리 경로(zlib+struct)로 생성
    python tools/generate_sprites.py --out DIR  # 다른 폴더에 생성 (비교·검증용)

Pillow 가 설치되어 있으면 PIL 로, 없으면 순수 파이썬 래스터라이저와 zlib+struct PNG 인코더로 만든다.
이미 존재하는 PNG 는 덮어쓰지 않고 그대로 보존한다 — 손으로 그린 아이콘으로 바꿔 넣어도 다시 실행해 지워지지 않는다.
(다시 만들고 싶은 파일은 직접 지운 뒤 실행한다.)

유물 색·도형과 몬스터 색은 data/items.lua · data/enemies.lua 에서 읽는다 (게임과 단일 출처).
data/enemies.lua 에서 sprite = "<다른 몬스터>" 인 중간 보스는 그 몬스터의 그림을 다시 쓰므로 만들지 않는다.
data/art.lua 의 monsters · items 에 올라 있는 id 는 원화(tools/extract_sprites.py)를 쓰므로 만들지 않는다.
파일 이름: item_<원형 id>.png · monster_<몬스터 id>.png · tex_wood.png · tex_stone.png  → ui/SpriteBank.lua 가 로드한다.
"""

import os
import random
import re
import sys

import sprite_art
import sprite_art_special
import sprite_canvas
import sprite_world

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = sprite_canvas.SIZE
EXPECTED_ITEMS = 32
ITEM_ART = dict(sprite_art.ITEM_ART, **sprite_art_special.ITEM_ART)
COLOR = r"\{\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\}"


def read_block(path, table_name):
    """Lua 데이터 파일에서 '    <table_name> = {' 블록의 줄들을 꺼낸다."""
    lines, inside = [], False
    with open(path, encoding="utf-8") as source:
        for line in source:
            if re.match(r"^    %s = \{\s*$" % table_name, line):
                inside = True
            elif inside and re.match(r"^    \},?\s*$", line):
                break
            elif inside:
                lines.append(line)
    if not lines:
        raise SystemExit("could not find table '%s' in %s" % (table_name, path))
    return lines


def parse_entries(path, table_name, fields):
    """'        <id> = {' 로 시작하는 항목마다 fields(이름 → 정규식)의 첫 일치를 모은다."""
    entries, current = {}, None
    for line in read_block(path, table_name):
        start = re.match(r"^        (\w+) = \{", line)
        if start:
            current = entries.setdefault(start.group(1), {})
        if current is None:
            continue
        for name, pattern in fields.items():
            found = re.search(pattern, line)
            if found and name not in current:
                groups = found.groups()
                current[name] = groups[0] if len(groups) == 1 else tuple(float(v) for v in groups)
    return entries


def load_items():
    items = parse_entries(os.path.join(ROOT, "data", "items.lua"), "prototypes", {
        "shape": r'shape = "(\w+)"', "primary": r"\bcolor = " + COLOR, "accent": r"\baccent = " + COLOR,
    })
    for item_id, entry in items.items():
        missing = [key for key in ("shape", "primary", "accent") if key not in entry]
        if missing or entry["shape"] not in ITEM_ART:
            raise SystemExit("item '%s' is missing %s or has no art recipe" % (item_id, missing or entry.get("shape")))
    if len(items) != EXPECTED_ITEMS:
        raise SystemExit("expected %d item prototypes in data/items.lua, found %d" % (EXPECTED_ITEMS, len(items)))
    return items


def load_monsters():
    monsters = parse_entries(os.path.join(ROOT, "data", "enemies.lua"), "monsters",
                             {"color": r"\bcolor = " + COLOR, "sprite": r'sprite = "(\w+)"'})
    monsters = {key: entry for key, entry in monsters.items() if "sprite" not in entry}
    for monster_id in monsters:
        if monster_id not in sprite_world.MONSTER_ART or "color" not in monsters[monster_id]:
            raise SystemExit("monster '%s' has no color or no art recipe" % monster_id)
    return monsters


def hand_drawn(table_name):
    """data/art.lua 에서 원화를 쓰는 id 집합."""
    return set(parse_entries(os.path.join(ROOT, "data", "art.lua"), table_name, {}))


def build_jobs():
    """(파일 이름, 그리는 함수(use_pil) → RGBA bytearray) 목록."""
    jobs = []
    drawn_items, drawn_monsters = hand_drawn("items"), hand_drawn("monsters")

    def drawn(painter, seed):
        def render(use_pil):
            canvas = sprite_canvas.Canvas(SIZE, use_pil)
            painter(canvas)
            return sprite_canvas.stylize(canvas.pixels(), SIZE, seed)
        return render

    for index, (item_id, entry) in enumerate(sorted(load_items().items())):
        if item_id in drawn_items:
            continue
        art = ITEM_ART[entry["shape"]]
        jobs.append(("item_%s.png" % item_id,
                     drawn(lambda c, art=art, e=entry: art(c, e["primary"], e["accent"]), 100 + index)))
    for index, (monster_id, entry) in enumerate(sorted(load_monsters().items())):
        if monster_id in drawn_monsters:
            continue
        art = sprite_world.MONSTER_ART[monster_id]
        jobs.append(("monster_%s.png" % monster_id, drawn(lambda c, art=art, e=entry: art(c, e["color"]), 200 + index)))
    for index, (name, art) in enumerate(sorted(sprite_world.TEXTURE_ART.items())):
        jobs.append(("tex_%s.png" % name, lambda use_pil, art=art, seed=300 + index: art(SIZE, random.Random(seed))))
    return jobs


def main(argv):
    use_pil = "--no-pil" not in argv
    out_dir = os.path.join(ROOT, "assets", "sprites")
    if "--out" in argv:
        out_dir = os.path.abspath(argv[argv.index("--out") + 1])
    os.makedirs(out_dir, exist_ok=True)
    backend = "Pillow" if (sprite_canvas.HAVE_PIL and use_pil) else "standard library (zlib + struct)"
    print("backend: %s  ->  %s" % (backend, out_dir))

    created, kept = 0, 0
    for filename, render in build_jobs():
        path = os.path.join(out_dir, filename)
        if os.path.exists(path):
            kept += 1
            print("keep   %s (already exists - not overwritten)" % filename)
            continue
        sprite_canvas.save_png(path, SIZE, render(use_pil), use_pil)
        created += 1
        print("create %s" % filename)
    print("done: %d created, %d kept" % (created, kept))


if __name__ == "__main__":
    main(sys.argv[1:])
