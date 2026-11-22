"""tools/sprite_black_bg.py — 순흑색(#000000) 배경 시트 전용 추출 (assets/sheets/armors.png).

종이색(#F2EFE9) 시트를 다루는 extract_sprites.py 의 key_out 과는 완전히 다른 경로다 (그쪽 로직은 건드리지 않는다).
검은 배경 시트는 그림의 먹 외곽선·안쪽 그림자도 배경과 같은 검정이고, 그림 둘레에는 그림 색만큼 밝은 글로우(후광)가
깔려 있어서 "배경색과 가까우면 지운다" 로는 그림이 파이거나 후광이 남는다. 대신 이 시트의 성질 두 가지를 쓴다:
    · 후광과 먼 배경은 매끈하고(국소 질감 거의 0), 그림은 얼룩덜룩한 질감이 있다 (TEX_MIN 으로 가른다)
    · 그림의 테두리는 검은 먹선이라, 바깥에서 밀고 들어온 플러드필이 거기서 멈춘다

  1. 셀 분할: 시트를 cols x rows 로 나눈다 (3행 4열) — 경계는 등분선 근처에서 그림 색이 가장 적은 줄 (이웃 그림이 넘어오지 않게).
  2. 바깥(1차): 셀 테두리에서 '매끈하고 검지 않은' 곳(후광)과 먼 배경을 따라 플러드필. 시트에 알파 매트가 있으면
     매트 밖을 먼 배경으로 본다 (없으면 넓은 검정). 검은 곳은 지나가지 않으므로 먹선과 안쪽 그림자(투구 속 · 목 구멍)는 남는다.
  3. 바깥(2차): 그림 가장자리의 질감에 가려 남은 후광 띠를 FRINGE px 까지 더 민다 — 검정(먹 외곽선)에서 멈추고,
     후광보다 밝은 색(GLOW_MAX 초과)으로는 들어가지 않는다 (안쪽 그림자·그림 색이 파이지 않게).
  4. 형태 보정: 몸통과 이어지지 않은 부스러기 제거 → 갇힌 구멍 메우기 → 2px 닫기로 가장자리 정리.
  5. 외곽 먹선: 실루엣 바깥 테두리에 진한 먹색(#120E0B)을 둘러 후광 잔여색을 덮는다 (줄인 뒤 1~2px).

사용: extract_sprites.py 의 main() 이 extract_black_sheet(...) 를 부른다. 단독 실행하면 방어구만 다시 뽑고
어두운 UI 슬롯 색 배경의 컨택트 시트(contact=경로)를 만든다:
    python tools/sprite_black_bg.py [컨택트 시트 경로]
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEETS = os.path.join(ROOT, "assets", "sheets")
OUT = os.path.join(ROOT, "assets", "sprites")

FAR_MAX = 9          # 이 밝기(최대 채널) 이하 = 검정 (먼 배경 · 먹선 · 안쪽 그림자)
OBJECT_MIN = 40      # 셀 경계를 찾을 때 그림 색으로 세는 밝기
TEX_MIN = 8          # 국소 질감(8배 확대 편차)이 이보다 작으면 매끈한 곳 = 후광 · 먼 배경 (후광 0~2, 그림 15~)
GLOW_MAX = 64        # 후광 밝기 상한 — 2차로 밀 때 이보다 밝은 색으로는 들어가지 않는다
FRINGE = 10          # 2차로 미는 거리(px)
FAR_REACH = 5        # 알파 매트가 없을 때: 이 반지름만큼 온통 검정이어야 먼 배경
SPLIT_SEARCH = 0.09  # 셀 경계를 찾는 범위 (시트 변 길이 대비, 등분선 양쪽)
INK = (0x12, 0x0E, 0x0B)
SLOT_BG = (26, 24, 32)       # 컨택트 시트 배경: 어두운 UI 슬롯 색

# 3행 4열 — 행: 투구 · 갑옷 · 신발 / 열: 일반 · 길드 강철 · 황금 룬 공명 · 심연 균열 (data/armors.lua 의 id 순서)
ARMOR_NAMES = [
    "kettle_helm", "guild_sallet", "rune_greathelm", "rift_horned_helm",
    "leather_jerkin", "guild_plate", "rune_cuirass", "rift_carapace",
    "leather_boots", "guild_greaves", "rune_sabatons", "rift_striders",
]


def _mask_image(mask):
    return Image.fromarray(np.where(mask, 255, 0).astype(np.uint8), "L")


def _grow(mask, radius):
    return np.asarray(_mask_image(mask).filter(ImageFilter.MaxFilter(radius * 2 + 1))) > 0


def _shrink(mask, radius):
    return np.asarray(_mask_image(mask).filter(ImageFilter.MinFilter(radius * 2 + 1))) > 0


def _flood_from_border(passable):
    """셀 테두리와 이어진 passable 영역 (4방향). 테두리 바깥에 1px 통로를 둘러 한 번에 채운다."""
    h, w = passable.shape
    canvas = np.zeros((h + 2, w + 2), np.uint8)
    canvas[1:-1, 1:-1] = np.where(passable, 0, 255)
    image = Image.fromarray(canvas, "L").copy()      # fromarray 는 읽기 전용 버퍼 — 복사해야 채워진다
    ImageDraw.floodfill(image, (0, 0), 128)
    return np.asarray(image)[1:-1, 1:-1] == 128


def _texture(level):
    """국소 질감: 흐린 것과의 편차(8배)를 다시 흐린 값. 매끈한 후광 ≈ 0~2, 그림 ≈ 15~."""
    image = Image.fromarray(level.astype(np.uint8), "L")
    blur = np.asarray(image.filter(ImageFilter.GaussianBlur(4))).astype(np.float64)
    deviation = np.clip(np.abs(level - blur) * 8, 0, 255).astype(np.uint8)
    return np.asarray(Image.fromarray(deviation, "L").filter(ImageFilter.GaussianBlur(3)))


def _connected_to(core, shape):
    """shape 안에서 core 와 이어진 부분만 (측지 팽창을 멈출 때까지 되풀이)."""
    core = core & shape
    for _ in range(400):
        grown = _grow(core, 3) & shape
        if grown.sum() == core.sum():
            break
        core = grown
    return core


def silhouette(rgba):
    """검은 배경 셀(RGBA) → 그림 실루엣(bool). 먹 외곽선과 안쪽 그림자를 포함한다."""
    rgb = Image.fromarray(rgba[..., :3].astype(np.uint8), "RGB")
    level = np.asarray(rgb.filter(ImageFilter.MedianFilter(5))).max(axis=2).astype(np.float64)
    low = level <= FAR_MAX
    matte = rgba[..., 3] >= 128
    if matte.all() or not matte.any():                                # 알파 매트가 없는 시트: 넓은 검정 = 먼 배경
        matte = ~(_grow(_flood_from_border(_shrink(low, FAR_REACH)), FAR_REACH + 1) & low)
    glow = (_texture(level) < TEX_MIN) & ~low                         # 매끈하고 검지 않은 곳 = 후광
    outside = _flood_from_border(~matte | _shrink(glow, 1))           # 1px 틈으로는 새지 않게
    soft = ~low & (level <= GLOW_MAX)
    for _ in range(FRINGE // 2):                                      # 가장자리 질감에 가려 남은 후광 띠
        outside = outside | (_grow(outside, 2) & soft)
    shape = matte & ~outside
    shape = _connected_to(_shrink(shape, 6), shape)                   # 몸통과 이어진 것만 (부스러기 제거)
    shape = ~_flood_from_border(~shape)                               # 갇힌 구멍(안쪽 그림자) 메우기
    return _shrink(_grow(shape, 2), 2)                                # 가장자리 닫기


def cut_cell(cell, line):
    """실루엣 밖은 투명, 바깥 테두리 line px 는 진한 먹색. cell: RGBA 배열, 반환: RGBA float 배열."""
    shape = silhouette(cell)
    outer = _grow(shape, line)
    rim = outer & ~_shrink(shape, max(1, line // 2))
    rgba = np.zeros(cell.shape[:2] + (4,), np.float64)
    rgba[..., :3] = cell[..., :3]
    rgba[rim, :3] = INK
    rgba[..., 3] = np.where(outer, 255.0, 0.0)
    return rgba


def _cuts(profile, count):
    """등분선 근처에서 그림 색이 가장 적은 줄로 나눈 경계 목록 [0, ..., 길이]."""
    size = len(profile)
    reach = int(size * SPLIT_SEARCH)
    cuts = [0]
    for i in range(1, count):
        mid = size * i // count
        lo, hi = mid - reach, mid + reach
        smooth = np.convolve(profile[lo:hi], np.ones(9) / 9, mode="same")
        best = np.flatnonzero(smooth <= smooth.min() + 0.5)
        cuts.append(lo + int(best[np.argmin(np.abs(best - reach))]))      # 가장 한적한 줄 중 등분선에 가까운 것
    return cuts + [size]


def extract_black_sheet(path, cols, rows, max_side):
    """시트를 cols x rows 로 나눠 [(RGBA PIL.Image), ...] (행 → 열 순서). 긴 변을 max_side 로 줄인다."""
    sheet = np.asarray(Image.open(path).convert("RGBA"))
    bright = sheet[..., :3].max(axis=2) >= OBJECT_MIN
    if (sheet[..., 3] < 128).any():                                   # 알파 매트가 있으면 그것으로 센다 (밝은 후광 제외)
        bright = bright & (sheet[..., 3] >= 128)
    ys, xs = _cuts(bright.sum(axis=1), rows), _cuts(bright.sum(axis=0), cols)
    line = max(2, round(1.5 * max(sheet.shape[1] / cols, sheet.shape[0] / rows) * 0.7 / max_side))   # 줄인 뒤 약 1.5px
    images = []
    for row in range(rows):
        for col in range(cols):
            cell = sheet[ys[row]:ys[row + 1], xs[col]:xs[col + 1]]
            image = Image.fromarray(cut_cell(cell, line).round().astype(np.uint8), "RGBA")
            image = image.crop(image.getchannel("A").getbbox())
            scale = min(1.0, max_side / max(image.size))
            size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
            image = image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
            padded = Image.new("RGBA", (image.width + 16, image.height + 16), (0, 0, 0, 0))
            padded.alpha_composite(image, (8, 8))
            images.append(padded)
    return images


def save_armors(max_side=256):
    """assets/sheets/armors.png → assets/sprites/armor_<id>.png 12장. 시트가 없으면 건너뛴다."""
    path = os.path.join(SHEETS, "armors.png")
    if not os.path.exists(path):
        print("skip armors.png (missing)")
        return []
    os.makedirs(OUT, exist_ok=True)
    images = extract_black_sheet(path, 4, 3, max_side)
    for image, name in zip(images, ARMOR_NAMES):
        image.save(os.path.join(OUT, "armor_" + name + ".png"))
        print("armor_%s.png %dx%d" % (name, image.width, image.height))
    return images


def contact_sheet(images, path, cols=4, tile=300):
    """어두운 UI 슬롯 색 배경 위에 늘어놓은 검수용 시트."""
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * tile, rows * tile), SLOT_BG + (255,))
    for i, image in enumerate(images):
        x = (i % cols) * tile + (tile - image.width) // 2
        y = (i // cols) * tile + (tile - image.height) // 2
        sheet.alpha_composite(image, (x, y))
    sheet.convert("RGB").save(path)


if __name__ == "__main__":
    made = save_armors()
    if len(sys.argv) > 1 and made:
        contact_sheet(made, sys.argv[1])
    sys.exit(0)
