#!/usr/bin/env python3
"""아트 시트 → 개별 스프라이트 추출기 (Pillow + numpy).

    python tools/extract_sprites.py

assets/sheets/ 의 종이색 시트 14장에서 밝은 종이 배경(#F2EFE9 계열)을 투명하게 지우고, 다크 웜톤 색보정과 종이 질감 그레인을
입혀 assets/sprites/ 에 데이터 id 와 같은 이름의 PNG 로 저장한다 (시트를 고쳤으면 다시 실행 — 결과 파일은 덮어쓴다).
  shopkeeper.png       → shopkeeper.png (주인장 상반신)
  buildings.png (1x2)  → building_workshop.png (왼쪽 공방 — 인트로·엔딩·밤 레인 방벽) · building_portal.png (오른쪽 포탈)
  monsters_weapons.png → goblin.png (좌상) · slime.png (우상) · flame_sword.png (좌하) · lightning_orb.png (우하)
  bosses.png (2x2)     → gatekeeper_golem · greed_raider (위) / abyss_necromancer · rift_lord (아래)
  boss_master.png      → boss_master.png ('스승의 흔적' 최종 보스 — 균열에 삼켜진 스승의 잔영, 한 장 전체)
  protagonist_battle.png (1x3) → protagonist_idle · protagonist_attack · protagonist_block (밤 전투 레인의 주인공 — 대기 · 공격 · 방어).
                         원본 3열(방어)은 왼쪽을 보고 있어 추출할 때 좌우로 뒤집는다 → 세 포즈 모두 오른쪽(포탈 쪽)을 본다.
                         세 포즈는 같은 배율로 줄인다 (포즈를 바꿔도 몸 크기가 달라지지 않게)
  monsters_extra.png   → ogre · shield_bearer (위) / shadow_assassin · skeleton (아래)
  special_relics.png   → starforge_hammer · bloodmoon_chalice · abyss_crown · golem_heart (위 4)
                         raider_sack · necro_codex · rift_prism · tycoon_ledger (아래 4)
  adventurers.png (2x3) → adventurer_bern · adventurer_rina · adventurer_ellen (위)
                         adventurer_thorin · adventurer_kain · adventurer_cedric (아래) — 손님 카운터 초상
  relics_base_1.png    → frost_crossbow · cursed_dagger · mana_crystal · tuning_fork (위 4)
                         rune_tablet · golden_chalice · guardian_crest · greed_pouch (아래 4)
  relics_base_2.png    → inferno_musket · ember_brazier · phoenix_feather · magma_core (위 4)
                         storm_rod · overdrive_coil · cooling_fins · bloodstone_idol (아래 4)
  relics_base_3.png    → hex_scythe · grave_lantern · blood_pact_scroll (위 3)
                         midas_gauntlet · merchant_scale · coin_golem (아래 3)
  ui_props.png (3x4)   → ui_lever_base · ui_lever_handle · ui_grid_slot · ui_storage_slot (위 4 — 과부하 레버 · 칸 타일)
                         icon_gold · icon_stone · icon_ward · icon_guild (가운데 4 — 상단 바 아이콘)
                         icon_quest · icon_compendium · icon_upgrade · icon_settings (아래 4)
  hammer_anvil.png     → cursor_hammer.png (위 망치 — 시계 방향 30° 돌려 손잡이가 오른쪽 아래, 마우스 커서)
                         ui_anvil.png (아래 모루 — 낮 용광로 칸 바닥). 단색 검정 실루엣이라 ink_metal 로
                         굵은 잉크 테두리 + 철·나무·황동 음영 + 윗면 하이라이트를 입힌다
  armors.png (3x4)     → armor_<id>.png 12장 (방어구 — 순흑색 배경이라 이 파일의 종이색 로직이 아니라
                         tools/sprite_black_bg.py 의 전용 경로로 뽑는다. main() 끝에서 save_armors() 를 부른다)
게임(ui/SpriteBank · ui/SpriteCatalog)은 같은 이름의 파일을 생성 스프라이트(item_* / monster_*)보다 먼저 쓴다. 표시 배율·좌우 뒤집기는 data/art.lua.

배경 판정: ① 시트 가장자리와 이어진 배경색 영역(느슨한 기준, 경계 번짐까지) ② 그림 안쪽에 갇힌 배경색 틈(엄격한 기준).
경계 2px 은 배경색과의 거리로 반투명 알파를 주고 배경색을 덜어 내 흰 테두리(헤일로)가 남지 않게 한다.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from sprite_black_bg import save_armors

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEETS = os.path.join(ROOT, "assets", "sheets")
OUT = os.path.join(ROOT, "assets", "sprites")

LOOSE = 52          # 가장자리와 이어진 배경으로 볼 색 거리
STRICT = 20         # 그림 안쪽 틈도 배경으로 볼 색 거리 (종이색과 거의 같은 색)
EDGE_LO, EDGE_HI = 12, 75   # 경계 반투명 알파: 이 거리 범위에서 0 → 1
WARM = np.array([0.965, 0.93, 0.87])    # 다크 웜톤 (R·G·B 배율)
GRAIN = 5.0         # 종이 질감 그레인 세기 (0~255 단위 표준편차)


def background_color(rgb):
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    return np.median(border, axis=0)


def background_mask(rgb, bg):
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    h, w = dist.shape
    loose = Image.fromarray(np.where(dist < LOOSE, 255, 0).astype(np.uint8), "L")
    for x in list(range(0, w, 12)) + [w - 1]:          # 가장자리에서 이어진 배경을 128 로 칠한다
        for y in (0, h - 1):
            if loose.getpixel((x, y)) == 255:
                ImageDraw.floodfill(loose, (x, y), 128)
    for y in list(range(0, h, 12)) + [h - 1]:
        for x in (0, w - 1):
            if loose.getpixel((x, y)) == 255:
                ImageDraw.floodfill(loose, (x, y), 128)
    connected = np.array(loose) == 128
    return connected | (dist < STRICT), dist


def key_out(sheet):
    """배경을 지운 RGBA 배열 (float, 0~255)."""
    rgb = np.array(sheet.convert("RGB")).astype(np.float64)
    bg = background_color(rgb)
    mask, dist = background_mask(rgb, bg)
    near = np.array(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    alpha = np.ones(dist.shape)
    edge = near & ~mask
    alpha[edge] = np.clip((dist[edge] - EDGE_LO) / (EDGE_HI - EDGE_LO), 0, 1)
    alpha[mask] = 0
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.where(edge[..., None], (rgb - (1 - alpha[..., None]) * bg) / safe, rgb)   # 배경색 덜어 내기
    return np.dstack([np.clip(rgb, 0, 255), alpha * 255])


def defringe(rgba, reach=2):
    """배경과 맞닿은 테두리 reach px 의 색을 이웃 중 가장 어두운 값(안쪽 잉크 외곽선)으로 낮춘다 — 밝은 종이색 헤일로 제거.
    외곽선 가장자리에 종이색이 번져 남는 시트(boss_master · protagonist_battle)에만 쓴다 (다른 시트의 결과는 그대로)."""
    alpha = rgba[..., 3]
    clear = Image.fromarray(np.where(alpha <= 8, 255, 0).astype(np.uint8), "L")
    rim = (np.array(clear.filter(ImageFilter.MaxFilter(reach * 2 + 1))) > 0) & (alpha > 8)
    rgb = rgba[..., :3].copy()
    rgb[alpha <= 8] = 255                           # 투명한 곳은 최솟값 계산에서 빠지게
    dark = np.array(Image.fromarray(rgb.round().astype(np.uint8), "RGB").filter(ImageFilter.MinFilter(reach * 2 + 1)))
    out = rgba.copy()
    out[..., :3] = np.where(rim[..., None], np.minimum(rgba[..., :3], dark.astype(np.float64)), rgba[..., :3])
    return out


def grade(rgba, seed):
    """다크 웜톤 색보정 + 종이 질감 그레인 (불투명한 곳만)."""
    rng = np.random.default_rng(seed)
    out = rgba.copy()
    out[..., :3] *= WARM
    grain = rng.normal(0, GRAIN, out.shape[:2])
    grain = np.array(Image.fromarray(np.clip(grain * 8 + 128, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)))
    out[..., :3] += ((grain.astype(np.float64) - 128) / 8)[..., None]
    out[..., :3] = np.clip(out[..., :3], 0, 255)
    return out


def ink_metal(rgba, zones, seed, ink=6, rim=(0.86, 0.68, 0.34)):
    """단색 실루엣 → 굵은 잉크 테두리 + 금속 음영. zones: [(x 시작 비율, x 끝 비율, 위 색, 아래 색)] (0~1 RGB).
    윗면(위쪽 경계 안쪽)에는 rim 색 하이라이트를 얹는다."""
    alpha = rgba[..., 3]
    solid = (alpha > 128).astype(np.uint8) * 255
    inner = np.array(Image.fromarray(solid).filter(ImageFilter.MinFilter(ink * 2 + 1))) > 0
    ys, xs = np.nonzero(solid)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    h, w = alpha.shape
    t = np.clip((np.arange(h)[:, None] - y0) / max(1, y1 - y0), 0, 1)[..., None]
    u = np.broadcast_to((np.arange(w)[None, :] - x0) / max(1, x1 - x0), (h, w))
    color = np.zeros((h, w, 3))
    for a, b, top, bottom in zones:
        band = np.array(top)[None, None, :] * (1 - t) + np.array(bottom)[None, None, :] * t
        color = np.where(((u >= a) & (u <= b))[..., None], band, color)
    lit = inner & ~np.roll(inner, 5, axis=0)                     # 윗면 5px
    color = np.where(lit[..., None], color * 0.4 + np.array(rim) * 0.6, color)
    out = np.zeros(rgba.shape)
    out[..., :3] = np.where(inner[..., None], color * 255, 10)  # 안쪽 = 금속, 바깥 띠 = 잉크
    out[..., 3] = alpha
    return grade(out, seed)


def split_index(alpha, axis, lo, hi):
    """lo~hi 비율 구간에서 불투명 픽셀이 가장 적은 열(axis=0) / 행(axis=1)."""
    counts = (alpha > 8).sum(axis=axis)
    a, b = int(len(counts) * lo), int(len(counts) * hi)
    return a + int(np.argmin(counts[a:b]))


def cells_2x2(rgba):
    """2x2 배열 시트 → [좌상, 우상, 좌하, 우하] (가운데 빈 열로 나눈 뒤, 양쪽을 각각 빈 행으로 나눈다)."""
    col = split_index(rgba[..., 3], 0, 0.4, 0.6)
    left, right = rgba[:, :col], rgba[:, col:]
    row_left = split_index(left[..., 3], 1, 0.3, 0.7)
    row_right = split_index(right[..., 3], 1, 0.3, 0.7)
    return [left[:row_left], right[:row_right], left[row_left:], right[row_right:]]


def cells_rows(rgba, cols, rows):
    """행을 먼저 빈 행으로 나누고, 각 행을 cols 칸으로 나눈다 (위 → 아래, 왼쪽 → 오른쪽)."""
    alpha = rgba[..., 3]
    ys = [0] + [split_index(alpha, 1, k / rows - 0.12, k / rows + 0.12) for k in range(1, rows)] + [alpha.shape[0]]
    cells = []
    for r in range(rows):
        band = rgba[ys[r]:ys[r + 1]]
        xs = [0] + [split_index(band[..., 3], 0, k / cols - 0.08, k / cols + 0.08) for k in range(1, cols)] + [band.shape[1]]
        cells += [band[:, xs[c]:xs[c + 1]] for c in range(cols)]
    return cells


def save_cells(cells, names, max_side):
    for cell, name in zip(cells, names):
        save(to_image(cell, max_side), name + ".png")


def opaque_size(rgba):
    """불투명 영역(알파 > 8)의 너비, 높이."""
    box = Image.fromarray(rgba[..., 3].round().astype(np.uint8), "L").point(lambda v: 255 if v > 8 else 0).getbbox()
    return box[2] - box[0], box[3] - box[1]


def save_cells_same_scale(cells, names, max_side):
    """여러 칸을 같은 배율로 줄여 저장한다 (가장 긴 변이 max_side 가 되는 배율 — 포즈 시트용)."""
    scale = min(1.0, max_side / max(max(opaque_size(cell)) for cell in cells))
    for cell, name in zip(cells, names):
        save(to_image(cell, max_side, scale=scale), name + ".png")


def to_image(rgba, max_side, rotate=0, scale=None):
    """불투명 영역만 잘라 여백을 두고, 필요하면 돌리고, 긴 변을 max_side 로 줄인다 (scale 을 주면 그 배율로)."""
    image = Image.fromarray(rgba.round().astype(np.uint8), "RGBA")
    box = image.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    image = image.crop(box)
    if rotate:
        image = image.convert("RGBa").rotate(rotate, resample=Image.BICUBIC, expand=True).convert("RGBA")
        image = image.crop(image.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    scale = scale if scale is not None else min(1.0, max_side / max(image.size))
    if scale < 1:
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image = image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    padded = Image.new("RGBA", (image.width + 16, image.height + 16), (0, 0, 0, 0))
    padded.alpha_composite(image, (8, 8))
    return padded


def save(image, name):
    path = os.path.join(OUT, name)
    image.save(path, optimize=True)
    print("wrote assets/sprites/%-24s %4dx%-4d" % (name, image.width, image.height))


def load(name):
    path = os.path.join(SHEETS, name)
    if not os.path.exists(path):
        raise SystemExit("missing sheet: assets/sheets/" + name)
    return Image.open(path)


# 기본 유물 22종 시트: (파일, 그레인 시드, 열 수, 위 → 아래 · 왼쪽 → 오른쪽 데이터 id)
RELIC_SHEETS = [
    ("relics_base_1.png", 18, 4, ["frost_crossbow", "cursed_dagger", "mana_crystal", "tuning_fork",
                                  "rune_tablet", "golden_chalice", "guardian_crest", "greed_pouch"]),
    ("relics_base_2.png", 19, 4, ["inferno_musket", "ember_brazier", "phoenix_feather", "magma_core",
                                  "storm_rod", "overdrive_coil", "cooling_fins", "bloodstone_idol"]),
    ("relics_base_3.png", 20, 3, ["hex_scythe", "grave_lantern", "blood_pact_scroll",
                                  "midas_gauntlet", "merchant_scale", "coin_golem"]),
]

# UI 파츠·아이콘 시트 (3행 4열): (데이터 id, 긴 변 최대 픽셀) — 레버·칸 타일은 크게, 상단 바 아이콘은 작게
UI_PROPS = [
    ("ui_lever_base", 420), ("ui_lever_handle", 420), ("ui_grid_slot", 256), ("ui_storage_slot", 256),
    ("icon_gold", 160), ("icon_stone", 160), ("icon_ward", 160), ("icon_guild", 160),
    ("icon_quest", 160), ("icon_compendium", 160), ("icon_upgrade", 160), ("icon_settings", 160),
]


def main():
    os.makedirs(OUT, exist_ok=True)

    rgba = grade(key_out(load("shopkeeper.png")), 11)
    save(to_image(rgba, 900), "shopkeeper.png")

    rgba = grade(key_out(load("buildings.png")), 12)
    col = split_index(rgba[..., 3], 0, 0.4, 0.6)
    save(to_image(rgba[:, :col], 1000), "building_workshop.png")
    save(to_image(rgba[:, col:], 1000), "building_portal.png")

    goblin, slime, sword, orb = cells_2x2(grade(key_out(load("monsters_weapons.png")), 13))
    save_cells([goblin, slime], ["goblin", "slime"], 560)
    save(to_image(sword, 560, rotate=40), "flame_sword.png")     # 가로 검 → 대각선 아이콘 자세
    save(to_image(orb, 560), "lightning_orb.png")

    save_cells(cells_2x2(grade(key_out(load("bosses.png")), 14)),
               ["gatekeeper_golem", "greed_raider", "abyss_necromancer", "rift_lord"], 640)
    save(to_image(grade(defringe(key_out(load("boss_master.png"))), 24), 720), "boss_master.png")
    idle, attack, block = cells_rows(grade(defringe(key_out(load("protagonist_battle.png"))), 25), 3, 1)
    block = block[:, ::-1]                                       # 3열(방어)만 좌우 반전: 세 포즈 모두 오른쪽(포탈 쪽)을 본다
    save_cells_same_scale([idle, attack, block], ["protagonist_idle", "protagonist_attack", "protagonist_block"], 600)
    save_cells(cells_2x2(grade(key_out(load("monsters_extra.png")), 15)),
               ["ogre", "shield_bearer", "shadow_assassin", "skeleton"], 560)
    save_cells(cells_rows(grade(key_out(load("special_relics.png")), 16), 4, 2),
               ["starforge_hammer", "bloodmoon_chalice", "abyss_crown", "golem_heart",
                "raider_sack", "necro_codex", "rift_prism", "tycoon_ledger"], 320)
    save_cells(cells_rows(grade(key_out(load("adventurers.png")), 17), 3, 2),
               ["adventurer_" + name for name in ("bern", "rina", "ellen", "thorin", "kain", "cedric")], 512)
    for sheet, seed, cols, names in RELIC_SHEETS:
        save_cells(cells_rows(grade(key_out(load(sheet)), seed), cols, 2), names, 320)
    rgba = key_out(load("hammer_anvil.png"))
    row = split_index(rgba[..., 3], 1, 0.4, 0.6)
    hammer = ink_metal(rgba[:row], [(0.0, 0.31, (0.62, 0.62, 0.68), (0.24, 0.24, 0.29)),        # 쇠 머리
                                    (0.31, 1.0, (0.58, 0.38, 0.20), (0.30, 0.18, 0.09))], 22)   # 나무 자루
    save(to_image(hammer, 256, rotate=-30), "cursor_hammer.png")
    anvil = ink_metal(rgba[row:], [(0.0, 1.0, (0.50, 0.50, 0.56), (0.17, 0.17, 0.21))], 23)
    save(to_image(anvil, 256), "ui_anvil.png")
    props = cells_rows(grade(key_out(load("ui_props.png")), 21), 4, 3)
    for cell, (name, side) in zip(props, UI_PROPS):
        save(to_image(cell, side), name + ".png")
    save_armors()       # armors.png 은 순흑색 배경 — 전용 경로 (tools/sprite_black_bg.py), 위의 종이색 로직과 무관
    print("done")


if __name__ == "__main__":
    main()
    sys.exit(0)
