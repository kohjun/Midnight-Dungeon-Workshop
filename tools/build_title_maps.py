#!/usr/bin/env python3
"""Build 2.5D title scene depth map, RGBA packed masks, clean sign backdrop, and data/title_fx.lua.

Outputs under assets/title_fx/:
  1. depth.png       : 5-tier edge-preserved depth map (reuses existing file unless --force-depth;
                       runs Depth-Anything-V2-Base/Large-hf if available, else OpenCV/Pillow fallback)
  2. mask_env.png    : RGBA packed (R=sky, G=moon, B=cobblestone, A=dead tree & foliage)
  3. mask_fx.png     : RGBA packed (R=portal void, G=runes+brazier flames, B=amber windows,
                       A=lightning rim-light emphasis on distant mountain skyline & left roof/chimney)
  4. sign_sprite.png : transparent RGBA sprite of the hanging wooden sign
  5. title_clean.png : title.png with the hanging sign seamlessly inpainted behind it

Also writes normalized (0..1, top-down LÖVE coordinates) anchors & tuning into data/title_fx.lua.
"""

from pathlib import Path
import argparse
import gc
import numpy as np
from PIL import Image
import cv2

ROOT = Path(__file__).resolve().parent.parent
SRC_IMAGE = ROOT / "assets" / "backgrounds" / "title.png"
OUT_DIR = ROOT / "assets" / "title_fx"
DEBUG_DIR = ROOT / "scripts" / "debug_out"
DATA_LUA = ROOT / "data" / "title_fx.lua"


def poly_mask(h: int, w: int, pts: list[tuple[int, int]]) -> np.ndarray:
    m = np.zeros((h, w), dtype=np.uint8)
    arr = np.array(pts, dtype=np.int32).reshape((-1, 1, 2))
    cv2.fillPoly(m, [arr], 255)
    return m


def largest_component(binary: np.ndarray, min_area: int = 10) -> np.ndarray:
    num, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    out = np.zeros_like(binary)
    if num <= 1:
        return out
    best_lbl = -1
    best_area = min_area
    for lbl in range(1, num):
        area = int(stats[lbl, cv2.CC_STAT_AREA])
        if area > best_area:
            best_area = area
            best_lbl = lbl
    if best_lbl > 0:
        out[labels == best_lbl] = 255
    return out


def fill_holes(binary: np.ndarray) -> np.ndarray:
    h, w = binary.shape
    flood = binary.copy()
    mask = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(flood, mask, (0, 0), 255)
    return cv2.bitwise_or(binary, cv2.bitwise_not(flood))


def guided_filter_gray(guide: np.ndarray, src: np.ndarray, radius: int, eps: float) -> np.ndarray:
    ksize = (2 * radius + 1, 2 * radius + 1)
    mean_i = cv2.boxFilter(guide, cv2.CV_32F, ksize)
    mean_p = cv2.boxFilter(src, cv2.CV_32F, ksize)
    mean_ip = cv2.boxFilter(guide * src, cv2.CV_32F, ksize)
    cov_ip = mean_ip - mean_i * mean_p
    mean_ii = cv2.boxFilter(guide * guide, cv2.CV_32F, ksize)
    var_i = mean_ii - mean_i * mean_i
    a = cov_ip / (var_i + eps)
    b = mean_p - a * mean_i
    return cv2.boxFilter(a, cv2.CV_32F, ksize) * guide + cv2.boxFilter(b, cv2.CV_32F, ksize)


def normalize_depth(d: np.ndarray) -> np.ndarray:
    lo = float(np.percentile(d, 0.2))
    hi = float(np.percentile(d, 99.8))
    return np.clip((d - lo) / max(hi - lo, 1e-6), 0.0, 1.0).astype(np.float32)


def detect_mountain_ridgeline(rgb: np.ndarray) -> np.ndarray:
    """Snap distant left mountain ridgeline y(x) for x in [0, 640] using sky->mountain vertical gradient."""
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    grad_y = cv2.Sobel(cv2.GaussianBlur(gray, (5, 5), 1.0), cv2.CV_32F, 0, 1, ksize=3)

    anchors = np.array(
        [
            (0, 520), (40, 525), (82, 513), (114, 506), (155, 516), (192, 524),
            (216, 515), (246, 512), (282, 522), (308, 530), (334, 520), (362, 513),
            (382, 508), (406, 514), (432, 492), (460, 482), (484, 467), (508, 482),
            (524, 480), (548, 494), (564, 500), (582, 493), (608, 506), (640, 516),
        ],
        dtype=np.float32,
    )
    xs = np.arange(0, 641, dtype=np.float32)
    prior_y = np.interp(xs, anchors[:, 0], anchors[:, 1])
    snapped = prior_y.copy()

    for x in range(95, 641):
        py = int(round(prior_y[x]))
        y0, y1 = max(445, py - 14), min(555, py + 14)
        col_g = grad_y[y0:y1, x]
        best_dy = int(np.argmin(col_g))
        if col_g[best_dy] < -4.0:
            snapped[x] = float(y0 + best_dy)

    return cv2.GaussianBlur(snapped.reshape(1, -1).astype(np.float32), (9, 1), 0).ravel()


def estimate_depth_hf(pil_img: Image.Image) -> np.ndarray | None:
    """Attempt Hugging Face Depth-Anything-V2 (Large-hf -> Base-hf, local cache first)."""
    try:
        import torch
        from transformers import AutoImageProcessor, AutoModelForDepthEstimation
    except Exception as exc:
        print(f"[build_title_maps] torch/transformers unavailable ({exc}); using OpenCV fallback.")
        return None

    device = "cuda" if torch.cuda.is_available() else (
        "mps" if hasattr(torch.backends, "mps") and torch.backends.mps.is_available() else "cpu"
    )
    models = [
        "depth-anything/Depth-Anything-V2-Large-hf",
        "depth-anything/Depth-Anything-V2-Base-hf",
    ]
    for model_id in models:
        for local_only in (True, False):
            try:
                processor = AutoImageProcessor.from_pretrained(model_id, local_files_only=local_only)
                model = AutoModelForDepthEstimation.from_pretrained(model_id, local_files_only=local_only)
                model = model.to(device).eval()
                inputs = processor(images=pil_img, return_tensors="pt")
                inputs = {k: v.to(device) for k, v in inputs.items()}
                with torch.no_grad():
                    pred = model(**inputs).predicted_depth
                out = torch.nn.functional.interpolate(
                    pred.unsqueeze(1),
                    size=(pil_img.height, pil_img.width),
                    mode="bicubic",
                    align_corners=False,
                ).squeeze().cpu().numpy().astype(np.float32)
                del model, processor, inputs, pred
                gc.collect()
                if device == "cuda":
                    torch.cuda.empty_cache()
                print(f"[build_title_maps] Depth estimated with {model_id} (local_only={local_only}, device={device})")
                return normalize_depth(out)
            except Exception:
                continue
    return None


def estimate_depth_heuristic(rgb: np.ndarray) -> np.ndarray:
    """OpenCV/Pillow hierarchical depth fallback: dead tree -> workshop/cobble -> portal/cliff -> mountains -> sky."""
    h, w, _ = rgb.shape
    yy, xx = np.mgrid[0:h, 0:w]
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0
    d = np.zeros((h, w), dtype=np.float32)

    ridge_y = detect_mountain_ridgeline(rgb)
    ridge_grid = np.full((h, w), h + 10.0, dtype=np.float32)
    ridge_grid[:, : len(ridge_y)] = ridge_y[None, :]
    mtn = (xx < 640) & (yy >= ridge_grid)
    d = np.where(mtn, 0.12 + 0.10 * np.clip((yy - ridge_grid) / 240.0, 0.0, 1.0), d)

    # Right cliff & portal mass (brighter brown/tan stone vs dark night sky)
    warm = (rgb[:, :, 0].astype(np.float32) - rgb[:, :, 2].astype(np.float32)) > 4.0
    right_cliff = (xx > 940) & (yy > 80) & (warm | (yy > 340))
    d = np.where(right_cliff, np.maximum(d, 0.44 + 0.14 * np.clip((yy - 200.0) / 500.0, 0.0, 1.0)), d)

    # Central workshop & rocky base
    workshop = (xx >= 540) & (xx <= 985) & (yy >= 150) & (yy <= 660) & (warm | (gray > 0.16))
    workshop_m = fill_holes(cv2.morphologyEx(workshop.astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((21, 21), np.uint8)))
    d = np.where(workshop_m > 128, np.maximum(d, 0.56), d)

    # Foreground cobblestones & lower cliff slope
    fg_ground = (yy > 565) & (xx > 390)
    d = np.where(fg_ground, np.maximum(d, 0.60 + 0.36 * np.clip((yy - 565.0) / 203.0, 0.0, 1.0)), d)

    # Left foreground dead tree silhouette & bottom-left ledge
    luma = rgb.mean(axis=2)
    tree_zone = (xx < 225) & (yy > 185) & (luma < 14.0)
    tree_m = largest_component(tree_zone.astype(np.uint8) * 255, min_area=400)
    d = np.where(tree_m > 128, 0.88, d)
    d = np.where((xx < 380) & (yy > 640) & (luma < 26.0), np.maximum(d, 0.86), d)

    d = cv2.bilateralFilter(d, 11, 0.08, 14.0)
    d = guided_filter_gray(gray, d, radius=5, eps=0.004)
    return normalize_depth(d)


def refine_depth(rgb: np.ndarray, raw: np.ndarray, sign_binary: np.ndarray | None = None) -> np.ndarray:
    """Edge-preserving bilateral + guided refinement separating all 5 depth tiers cleanly."""
    h, w, _ = rgb.shape
    yy, xx = np.mgrid[0:h, 0:w]
    raw = normalize_depth(raw)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0

    d = np.power(np.clip(raw, 0.0, 1.0), 0.78).astype(np.float32)
    d_bi = cv2.bilateralFilter(cv2.bilateralFilter(d, 9, 0.06, 10.0), 13, 0.045, 16.0)
    d_gd = guided_filter_gray(gray, d_bi, radius=4, eps=0.003)
    d_ref = np.clip(0.35 * d_gd + 0.65 * d_bi, 0.0, 1.0)

    # Pure sky vs distant mountains
    ridge_y = detect_mountain_ridgeline(rgb)
    ridge_grid = np.full((h, w), h + 10.0, dtype=np.float32)
    ridge_grid[:, : len(ridge_y)] = ridge_y[None, :]
    in_mtn_band = (xx < 625) & (yy >= ridge_grid) & (raw < 0.24)
    mtn_soft = cv2.GaussianBlur(in_mtn_band.astype(np.float32), (5, 5), 0.9)
    mtn_target = 0.095 + 0.115 * np.clip((yy - ridge_grid) / 230.0, 0.0, 1.0)

    pure_sky = (raw < 0.05) & (~in_mtn_band)
    sky_soft = cv2.GaussianBlur(pure_sky.astype(np.float32), (5, 5), 0.8)
    d_ref = d_ref * (1.0 - 0.92 * sky_soft)
    d_ref = np.where(mtn_soft > 0.02, np.maximum(d_ref, mtn_target * mtn_soft), d_ref)

    # Left foreground dead tree boost
    tree_x = np.clip((245.0 - xx) / 25.0, 0.0, 1.0)
    tree_y = np.clip((yy - 165.0) / 15.0, 0.0, 1.0) * np.clip((735.0 - yy) / 85.0, 0.0, 1.0)
    tree_sil = np.clip((raw - 0.10) / 0.18, 0.0, 1.0) * tree_x * tree_y
    tree_target = 0.80 + 0.10 * np.clip((yy - 180.0) / 500.0, 0.0, 1.0)
    d_ref = d_ref * (1.0 - tree_sil) + np.maximum(d_ref, tree_target) * tree_sil

    # Gently recess rounded portal interior behind stone arch
    arch = poly_mask(
        h, w,
        [
            (1112, 578), (1107, 510), (1104, 430), (1110, 376),
            (1128, 338), (1154, 320), (1182, 318), (1210, 328),
            (1232, 354), (1243, 405), (1244, 510), (1234, 578),
        ],
    )
    void_soft = cv2.GaussianBlur(arch.astype(np.float32) / 255.0, (17, 17), 0)
    d_ref = d_ref * (1.0 - 0.26 * void_soft)

    # Remove hanging sign depth bump behind title_clean.png
    if sign_binary is not None:
        inpaint_m = cv2.dilate((sign_binary > 20).astype(np.uint8) * 255, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)))
        beam_y = 347.0 - (xx - 930.0) * (12.0 / 76.0)
        inpaint_m = np.where((yy >= beam_y) & (xx >= 933) & (xx <= 1012), inpaint_m, 0).astype(np.uint8)
        d_u8 = np.clip(d_ref * 255.0, 0, 255).astype(np.uint8)
        d_inp = cv2.inpaint(d_u8, inpaint_m, 9, cv2.INPAINT_TELEA).astype(np.float32) / 255.0
        blend = cv2.GaussianBlur(inpaint_m.astype(np.float32) / 255.0, (9, 9), 0)
        d_ref = d_ref * (1.0 - blend) + d_inp * blend

    return normalize_depth(cv2.bilateralFilter(d_ref.astype(np.float32), 7, 0.035, 7.0))


def extract_sign(rgb: np.ndarray, depth: np.ndarray):
    """Extract hanging wooden crescent-dagger sign sprite & clean inpainted background."""
    h, w, _ = rgb.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r, g, b = rgb[:, :, 0].astype(np.int16), rgb[:, :, 1].astype(np.int16), rgb[:, :, 2].astype(np.int16)

    beam_y = 347.0 - (xx - 930.0) * (12.0 / 76.0)
    below_beam = yy >= beam_y
    sign_roi = (xx >= 934) & (xx <= 1007) & (yy >= 336) & (yy <= 452) & below_beam
    not_flame = ~((xx > 996) & (yy > 400) & (b > g + 8) & (r > g + 15))
    not_cornice = ~((yy > 410) & (xx < (940.0 + (yy - 410.0) * 0.72)))
    wood = sign_roi & not_flame & not_cornice & (r > b + 8) & (r > 36) & (yy >= 346)

    board = cv2.morphologyEx(wood.astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    board = fill_holes(largest_component(board, min_area=500))

    board_dil = cv2.dilate(board, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
    dark_ink = (r < 42) & (g < 44) & (b < 54)
    shield_left = np.where(yy > 410, 940.0 + (yy - 410.0) * 0.75, 937.0)
    sign_ink = np.where((board > 0) | ((board_dil > 0) & dark_ink & sign_roi & not_flame & (xx >= shield_left)), 255, 0).astype(np.uint8)
    sign_ink = fill_holes(largest_component(sign_ink, min_area=500))

    chain_roi = (
        ((xx >= 944) & (xx <= 954) & (yy >= 342) & (yy <= 364))
        | ((xx >= 981) & (xx <= 993) & (yy >= 335) & (yy <= 358))
    ) & below_beam
    chain_px = chain_roi & (np.abs(r - b) < 18) & (r < 110)
    chain_clean = cv2.morphologyEx(chain_px.astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))

    sign_bin = largest_component(cv2.morphologyEx(cv2.bitwise_or(sign_ink, chain_clean), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)), min_area=600)
    mask_sign = cv2.GaussianBlur(sign_bin, (3, 3), 0.7)

    # Clean dark shadowed cliff inpainting behind the hanging sign
    inpaint_m = cv2.dilate(sign_bin, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    inpaint_m = np.where(below_beam & (xx >= 933) & not_flame, inpaint_m, 0).astype(np.uint8)
    telea = cv2.cvtColor(cv2.inpaint(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), inpaint_m, 9, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB)

    row_bg = np.zeros((h, 3), dtype=np.float32)
    for y in range(330, 460):
        sl = rgb[y, 1005:1022].astype(np.float32)
        ok = (sl[:, 0] < 60) & (sl[:, 2] < 75)
        row_bg[y] = np.median(sl[ok], axis=0) if np.any(ok) else np.array([18.0, 24.0, 36.0], dtype=np.float32)
    for c in range(3):
        row_bg[330:460, c] = cv2.GaussianBlur(row_bg[330:460, c].reshape(-1, 1), (1, 15), 0).ravel()

    cliff = np.zeros_like(rgb, dtype=np.float32)
    for y in range(330, 460):
        cliff[y, :, :] = row_bg[y]
    strata = np.sin(xx * 0.045 + yy * 0.032) * 3.5 + np.cos(xx * 0.09 - yy * 0.05) * 2.0
    for c in range(3):
        cliff[:, :, c] = np.clip(cliff[:, :, c] + strata, 6, 70)

    telea_brown = telea[:, :, 0].astype(np.int16) > telea[:, :, 2].astype(np.int16) + 4
    soft_m = cv2.GaussianBlur(inpaint_m.astype(np.float32) / 255.0, (7, 7), 0)
    fill = np.where(telea_brown[:, :, None], cliff, 0.72 * cliff + 0.28 * telea.astype(np.float32))
    title_clean = np.clip(rgb.astype(np.float32) * (1.0 - soft_m[:, :, None]) + fill * soft_m[:, :, None], 0, 255).astype(np.uint8)

    # Tight-cropped RGBA sign sprite with exact pivot offset inside the sprite!
    ys, xs = np.where(sign_bin > 128)
    pad = 4
    x0, y0 = max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad)
    x1, y1 = min(w, int(xs.max()) + pad + 1), min(h, int(ys.max()) + pad + 1)
    sprite_rgba = np.dstack([rgb[y0:y1, x0:x1], mask_sign[y0:y1, x0:x1]])

    pivot_px = [968.0, 337.0]
    sign_depth = float(np.percentile(depth[326:342, 938:996], 75))
    return sign_bin, title_clean, sprite_rgba, [x0, y0, x1 - x0, y1 - y0], pivot_px, sign_depth


def extract_masks(rgb: np.ndarray, raw_depth: np.ndarray, depth: np.ndarray):
    """Extract all 8 individual channel masks and pack into mask_env.png and mask_fx.png."""
    h, w, _ = rgb.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r, g, b = rgb[:, :, 0].astype(np.int16), rgb[:, :, 1].astype(np.int16), rgb[:, :, 2].astype(np.int16)
    luma = 0.299 * r.astype(np.float32) + 0.587 * g.astype(np.float32) + 0.114 * b.astype(np.float32)

    # 1) Sky & 2) Moon
    moon_roi = (xx >= 932) & (xx <= 1072) & (yy >= 30) & (yy <= 170)
    moon_bin = fill_holes(largest_component(cv2.morphologyEx(
        (moon_roi & (r > 118) & (g > 108) & (b > 86) & ((r - b) > 5)).astype(np.uint8) * 255,
        cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8),
    ), min_area=2000))
    mask_moon = cv2.GaussianBlur(moon_bin, (3, 3), 0.7)
    my, mx = np.where(moon_bin > 128)
    moon_center = [float(mx.mean()), float(my.mean())]
    moon_radius = float(np.sqrt(len(mx) / np.pi))

    ridge_y = detect_mountain_ridgeline(rgb)
    ridge_grid = np.full((h, w), h + 10.0, dtype=np.float32)
    ridge_grid[:, : len(ridge_y)] = ridge_y[None, :]
    sky_raw = ((raw_depth < 0.065) & (yy < ridge_grid - 1.0) & (yy < 540)).astype(np.uint8) * 255
    num, lbl, stats, _ = cv2.connectedComponentsWithStats(sky_raw, connectivity=8)
    sky_bin = np.zeros((h, w), dtype=np.uint8)
    seed_lbl = lbl[20, 650]
    if seed_lbl > 0:
        sky_bin[lbl == seed_lbl] = 255
    else:
        sky_bin = largest_component(sky_raw, min_area=20000)
    for i in range(1, num):
        if i != seed_lbl and stats[i, cv2.CC_STAT_LEFT] < 180 and stats[i, cv2.CC_STAT_TOP] < 515 and stats[i, cv2.CC_STAT_AREA] >= 15:
            sky_bin[lbl == i] = 255
    mask_sky = cv2.GaussianBlur(cv2.erode(sky_bin, np.ones((3, 3), np.uint8)), (5, 5), 1.0)

    # 3) Cobblestones
    path_poly = poly_mask(h, w, [
        (788, 613), (896, 616), (958, 628), (1045, 628), (1070, 618), (1238, 618),
        (1218, 636), (1145, 650), (1082, 666), (1040, 690), (1008, 725), (970, 768),
        (615, 768), (676, 742), (748, 718), (814, 692), (866, 672), (862, 656), (815, 642), (784, 628),
    ])
    steps_poly = poly_mask(h, w, [(1072, 581), (1245, 581), (1248, 622), (1055, 622)])
    corridor = cv2.bitwise_or(path_poly, steps_poly)
    stone = ((corridor > 0) & (r > 46) & (g > 36) & (r > b + 6) & (depth > 0.35)).astype(np.uint8) * 255
    closed = cv2.bitwise_and(cv2.morphologyEx(stone, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 9))), corridor)
    closed = cv2.morphologyEx(closed, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    num_c, lbl_c, stats_c, _ = cv2.connectedComponentsWithStats(closed, connectivity=8)
    cob_clean = np.zeros((h, w), dtype=np.uint8)
    for i in range(1, num_c):
        if stats_c[i, cv2.CC_STAT_AREA] >= 120:
            cob_clean[lbl_c == i] = 255
    mask_cobble = cv2.GaussianBlur(cob_clean, (7, 7), 1.6)
    cy_c, cx_c = np.where(cob_clean > 128)
    cobble_box = [int(cx_c.min()), int(cy_c.min()), int(cx_c.max() - cx_c.min()), int(cy_c.max() - cy_c.min())]

    # 4) Foliage (left dead tree twigs + cliff & path grass tufts)
    tree_bin = largest_component(((xx < 235) & (yy >= 180) & (yy <= 645) & (raw_depth > 0.13)).astype(np.uint8) * 255, min_area=500)
    dist_base = np.sqrt(((xx - 14.0) / 115.0) ** 2 + (np.maximum(0.0, 565.0 - yy) / 260.0) ** 2)
    tree_soft = cv2.GaussianBlur(tree_bin.astype(np.float32) / 255.0, (3, 3), 0.75) * np.clip((dist_base - 0.16) / 0.55, 0.0, 1.0)

    tuft_specs = [
        (46, 610, 108, 660, "sky_depth"), (152, 686, 206, 726, "sky_depth"),
        (1004, 248, 1040, 274, "sky_depth"), (1098, 174, 1134, 200, "sky_depth"),
        (1200, 92, 1246, 128, "sky_depth"), (494, 566, 530, 592, "sky_depth"),
        (596, 588, 634, 612, "rock"), (724, 630, 760, 654, "rock"),
        (914, 594, 954, 618, "rock"), (630, 720, 680, 760, "rock"),
        (748, 686, 792, 724, "rock"), (884, 670, 924, 696, "rock"),
        (1014, 614, 1052, 634, "rock"), (1074, 670, 1122, 700, "rock"),
        (1194, 610, 1232, 632, "rock"), (1018, 700, 1054, 734, "rock"),
    ]
    tuft_f = np.zeros((h, w), dtype=np.float32)
    luma_bh = cv2.morphologyEx(luma, cv2.MORPH_BLACKHAT, cv2.getStructuringElement(cv2.MORPH_RECT, (9, 3)))
    depth_th = cv2.morphologyEx(raw_depth, cv2.MORPH_TOPHAT, cv2.getStructuringElement(cv2.MORPH_RECT, (11, 5)))
    for x0, y0, x1, y1, mode in tuft_specs:
        if mode == "sky_depth":
            bl = ((depth_th[y0:y1, x0:x1] > 0.035) | ((luma_bh[y0:y1, x0:x1] > 4.5) & (raw_depth[y0:y1, x0:x1] > 0.12))).astype(np.float32)
        else:
            bl = ((luma_bh[y0:y1, x0:x1] > 7.5) & (luma[y0:y1, x0:x1] < 68.0)).astype(np.float32)
        vy = np.linspace(1.0, 0.0, y1 - y0).reshape(-1, 1)
        vx = 1.0 - np.abs(np.linspace(-1.0, 1.0, x1 - x0)).reshape(1, -1) ** 2
        env = np.clip(vy * 1.25, 0.0, 1.0) * np.clip(vx * 1.4, 0.0, 1.0)
        bl = cv2.GaussianBlur(cv2.dilate(bl, np.ones((2, 2), np.uint8)), (3, 3), 0.7) * env
        tuft_f[y0:y1, x0:x1] = np.maximum(tuft_f[y0:y1, x0:x1], bl)
    mask_foliage = (np.clip(np.maximum(tree_soft, tuft_f), 0.0, 1.0) * 255.0).round().astype(np.uint8)

    # 5) Portal Void
    arch_poly = poly_mask(h, w, [
        (1110, 582), (1105, 515), (1102, 430), (1108, 375), (1126, 336), (1152, 318),
        (1182, 316), (1212, 326), (1234, 352), (1245, 405), (1246, 515), (1235, 582),
    ])
    is_stone = (r > 52) & (g > 44) & ((r - b) > -4) & (g > 0.72 * r)
    is_void = (((r > g + 6) & (b > g + 8) & (r < 165) & (b < 175)) | ((r < 42) & (g < 34) & (b < 50)))
    void_bin = fill_holes(largest_component(cv2.morphologyEx(
        ((arch_poly > 0) & is_void & (~is_stone)).astype(np.uint8) * 255,
        cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)),
    ), min_area=5000))
    void_bin = cv2.erode(void_bin, np.ones((3, 3), np.uint8))
    mask_void = cv2.GaussianBlur(void_bin, (5, 5), 1.1)
    vy_p, vx_p = np.where(void_bin > 128)
    portal_center = [float(vx_p.mean()), float(vy_p.mean())]
    portal_box = [int(vx_p.min()), int(vy_p.min()), int(vx_p.max() - vx_p.min()), int(vy_p.max() - vy_p.min())]

    # 6) Portal Runes + Brazier Flames
    rune_rois = [
        (1148, 232, 1192, 302), (1050, 330, 1084, 378), (1050, 394, 1085, 464),
        (1264, 330, 1298, 378), (1265, 394, 1300, 464),
    ]
    rune_reg = np.zeros((h, w), dtype=bool)
    for x0, y0, x1, y1 in rune_rois:
        rune_reg |= (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)
    runes = cv2.GaussianBlur(cv2.morphologyEx((rune_reg & (r > 105) & (r > g + 24) & (b > g + 6)).astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)), (3, 3), 0.8)

    lb_roi = (xx >= 992) & (xx <= 1048) & (yy >= 398) & (yy <= 506)
    rb_roi = (xx >= 1298) & (xx <= 1356) & (yy >= 408) & (yy <= 512)
    fl_bin = cv2.morphologyEx(((lb_roi | rb_roi) & (r > 88) & (b > 88) & (r > g + 16) & (b > g + 16)).astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    num_f, lbl_f, stats_f, _ = cv2.connectedComponentsWithStats(fl_bin, connectivity=8)
    fl_clean = np.zeros((h, w), dtype=np.uint8)
    for i in range(1, num_f):
        if stats_f[i, cv2.CC_STAT_AREA] >= 12:
            fl_clean[lbl_f == i] = 255
    flames = cv2.GaussianBlur(fl_clean, (3, 3), 0.8)
    mask_glow = np.maximum(runes, flames)

    ly, lx = np.where((fl_clean > 128) & lb_roi & (yy < 475))
    ry, rx = np.where((fl_clean > 128) & rb_roi & (yy < 480))
    braz_l, braz_r = [float(lx.mean()), float(ly.mean())], [float(rx.mean()), float(ry.mean())]

    # 7) Amber Windows
    win2_roi = (xx >= 796) & (xx <= 840) & (yy >= 304) & (yy <= 367)
    win1_roi = (xx >= 667) & (xx <= 703) & (yy >= 472) & (yy <= 530)
    win_bin = ((win1_roi | win2_roi) & (r > 125) & (r > g + 22) & (g > b + 28) & (b < 95)).astype(np.uint8) * 255
    mask_windows = cv2.GaussianBlur(win_bin, (3, 3), 0.7)
    y1, x1 = np.where((win_bin > 128) & win1_roi)
    y2, x2 = np.where((win_bin > 128) & win2_roi)
    win_centers = [[float(x1.mean()), float(y1.mean())], [float(x2.mean()), float(y2.mean())]]

    # 8) Lightning Rim-Light Emphasis Mask (mask_fx.a):
    #    - Razor-thin 3px backlit distant mountain ridgeline (x in [70..625], excludes dead tree!)
    #    - Crisp 4px left-facing edge rim on central workshop roof, stone chimney, & left cliff
    rim = np.zeros((h, w), dtype=np.float32)

    # 8a. Distant mountain skyline rim (3px band just below ridge_y, excluded where dead tree is in front)
    mtn_rim = (xx >= 55) & (xx <= 622) & (yy >= ridge_grid - 1.0) & (yy <= ridge_grid + 3.5) & (raw_depth < 0.22)
    rim = np.maximum(rim, cv2.GaussianBlur(mtn_rim.astype(np.float32), (5, 5), 0.9) * 0.88)

    # 8b. Workshop left roof, chimney left silhouette, & left cliff rim facing left storm
    #     Use razor-sharp raw_depth step toward upper-left (-5px x, -4px y) in workshop/cliff x in [430..905]
    rd_shift = np.zeros_like(raw_depth)
    rd_shift[4:, 5:] = raw_depth[:-4, :-5]
    left_edge = np.clip((raw_depth - rd_shift - 0.07) / 0.14, 0.0, 1.0)
    workshop_zone = (xx >= 430) & (xx <= 905) & (yy >= 145) & (yy <= 645) & (raw_depth > 0.16)
    # Exclude far-left dead tree (x < 350) so tree stays pitch-black ink silhouette!
    roof_rim = cv2.GaussianBlur((left_edge * workshop_zone.astype(np.float32)), (5, 5), 0.85)
    rim = np.maximum(rim, np.clip(roof_rim * 1.25, 0.0, 1.0))
    mask_rim = (np.clip(rim, 0.0, 1.0) * 255.0).round().astype(np.uint8)

    # Pack straight RGBA channels
    mask_env = np.stack([mask_sky, mask_moon, mask_cobble, mask_foliage], axis=-1)
    mask_fx = np.stack([mask_void, mask_glow, mask_windows, mask_rim], axis=-1)

    anchors = {
        "moon_center": moon_center,
        "moon_radius": moon_radius,
        "portal_center": portal_center,
        "portal_box": portal_box,
        "portal_depth": float(np.median(depth[void_bin > 128])),
        "brazier_left": braz_l,
        "brazier_right": braz_r,
        "windows": win_centers,
        "cobble_box": cobble_box,
    }
    return mask_env, mask_fx, anchors


def write_title_fx_lua(w: int, h: int, sign_box, sign_pivot, sign_depth, anchors, chimney_px, chimney_depth):
    """Write data/title_fx.lua pure Lua table with normalized (0..1, top-down) anchors & FX tuning."""
    def nx(x): return round(x / w, 5)
    def ny(y): return round(y / h, 5)

    # Pivot inside cropped sign_sprite.png (in sprite-local pixels & normalized)
    sx, sy, sw, sh = sign_box
    piv_local_x = round(sign_pivot[0] - sx, 2)
    piv_local_y = round(sign_pivot[1] - sy, 2)

    content = f"""-- data/title_fx.lua
-- 타이틀 2.5D 배경 연출 수치 및 정규화 좌표(0~1, LÖVE 상단 원점). 로직 없음.
-- 좌표는 tools/build_title_maps.py 가 assets/backgrounds/title.png 기준으로 자동 기록한다.

return {{
    assets = {{
        clean = "assets/title_fx/title_clean.png",
        fallback = "assets/backgrounds/title.png",
        depth = "assets/title_fx/depth.png",
        mask_env = "assets/title_fx/mask_env.png",
        mask_fx = "assets/title_fx/mask_fx.png",
        sign = "assets/title_fx/sign_sprite.png",
        shader = "shaders/title_scene.glsl",
    }},

    image = {{ w = {w}, h = {h}, aspect = {round(w / h, 6)} }},

    parallax = {{
        zoom = 1.03,
        strength_x = 0.017,
        strength_y = 0.012,
        damp = 6.0,
        idle_x = 0.06,
        idle_y = 0.04,
    }},

    sign = {{
        pivot = {{ x = {nx(sign_pivot[0])}, y = {ny(sign_pivot[1])} }},
        box = {{ x = {nx(sx)}, y = {ny(sy)}, w = {nx(sw)}, h = {ny(sh)} }},
        sprite_pivot = {{ x = {piv_local_x}, y = {piv_local_y} }},
        depth = {round(sign_depth, 4)},
        stiffness = 22.0,
        damping = 1.8,
        max_angle = 0.48,
        wind_amp = 0.18,
        swipe_gain = 0.0085,
        max_vel = 3.5,
        creak_threshold = 0.14,
        creak_cooldown = 0.42,
    }},

    chimney = {{
        x = {nx(chimney_px[0])},
        y = {ny(chimney_px[1])},
        depth = {round(chimney_depth, 4)},
        rate = 4.2,
    }},

    portal = {{
        x = {nx(anchors["portal_center"][0])},
        y = {ny(anchors["portal_center"][1])},
        box = {{ x = {nx(anchors["portal_box"][0])}, y = {ny(anchors["portal_box"][1])}, w = {nx(anchors["portal_box"][2])}, h = {ny(anchors["portal_box"][3])} }},
        depth = {round(anchors["portal_depth"], 4)},
        brazier_left = {{ x = {nx(anchors["brazier_left"][0])}, y = {ny(anchors["brazier_left"][1])} }},
        brazier_right = {{ x = {nx(anchors["brazier_right"][0])}, y = {ny(anchors["brazier_right"][1])} }},
        ember_rate = 11.0,
    }},

    moon = {{
        x = {nx(anchors["moon_center"][0])},
        y = {ny(anchors["moon_center"][1])},
        radius = {round(anchors["moon_radius"] / w, 5)},
    }},

    windows = {{
        {{ x = {nx(anchors["windows"][0][0])}, y = {ny(anchors["windows"][0][1])} }},
        {{ x = {nx(anchors["windows"][1][0])}, y = {ny(anchors["windows"][1][1])} }},
    }},

    cobble = {{
        x = {nx(anchors["cobble_box"][0])},
        y = {ny(anchors["cobble_box"][1])},
        w = {nx(anchors["cobble_box"][2])},
        h = {ny(anchors["cobble_box"][3])},
        ripple_max = 8,
        ripple_life = 1.35,
        rain_ripple_rate = 5.5,
        cursor_ripple_cd = 0.11,
    }},

    lightning = {{
        interval_min = 6.0,
        interval_max = 14.0,
        first_min = 3.2,
        first_max = 6.0,
        duration_min = 0.15,
        duration_max = 0.24,
        thunder_delay_min = 0.4,
        thunder_delay_max = 1.2,
        depth = 0.14,
        sky_click = {{ x_min = 0.03, x_max = 0.47, y_min = 0.02, y_max = 0.68 }},
        bolt_x_min = 0.11,
        bolt_x_max = 0.42,
        bolt_end_y_min = 0.64,
        bolt_end_y_max = 0.74,
    }},

    rain = {{
        bg_count = 72,
        fg_count = 54,
        slant = -0.13,
        speed_bg = 520,
        speed_fg = 860,
    }},

    mist = {{
        count = 6,
        y_min = 0.62,
        y_max = 0.90,
        x_max = 0.54,
    }},
}}
"""
    DATA_LUA.write_text(content, encoding="utf-8")
    print(f"[build_title_maps] Wrote {DATA_LUA.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force-depth", action="store_true", help="Regenerate assets/title_fx/depth.png even if it exists")
    args = parser.parse_args()

    if not SRC_IMAGE.exists():
        raise SystemExit(f"Missing source illustration: {SRC_IMAGE}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    pil_img = Image.open(SRC_IMAGE).convert("RGB")
    rgb = np.array(pil_img)
    h, w, _ = rgb.shape

    depth_out = OUT_DIR / "depth.png"
    raw_cache = DEBUG_DIR / "depth_raw.png"

    # 1. Obtain or reuse depth.png
    if depth_out.exists() and not args.force_depth:
        print(f"[build_title_maps] Reusing existing {depth_out.relative_to(ROOT)}")
        depth = np.array(Image.open(depth_out).convert("L")).astype(np.float32) / 255.0
        raw_depth = (
            np.array(Image.open(raw_cache).convert("L")).astype(np.float32) / 255.0
            if raw_cache.exists()
            else depth
        )
        sign_bin, title_clean, sign_rgba, sign_box, sign_pivot, sign_depth = extract_sign(rgb, depth)
    else:
        if raw_cache.exists() and not args.force_depth:
            print(f"[build_title_maps] Using cached Depth-Anything-V2 raw depth: {raw_cache.relative_to(ROOT)}")
            raw_depth = np.array(Image.open(raw_cache).convert("L")).astype(np.float32) / 255.0
        else:
            raw_depth = estimate_depth_hf(pil_img)
            if raw_depth is None:
                raw_depth = estimate_depth_heuristic(rgb)
        prelim_depth = refine_depth(rgb, raw_depth, sign_binary=None)
        sign_bin, title_clean, sign_rgba, sign_box, sign_pivot, sign_depth = extract_sign(rgb, prelim_depth)
        depth = refine_depth(rgb, raw_depth, sign_binary=sign_bin)
        Image.fromarray((depth * 255.0).round().astype(np.uint8), mode="L").save(depth_out)
        print(f"[build_title_maps] Saved {depth_out.relative_to(ROOT)}")

    # 2. Extract and pack RGBA masks
    mask_env, mask_fx, anchors = extract_masks(rgb, raw_depth, depth)

    Image.fromarray(mask_env, mode="RGBA").save(OUT_DIR / "mask_env.png")
    Image.fromarray(mask_fx, mode="RGBA").save(OUT_DIR / "mask_fx.png")
    Image.fromarray(sign_rgba, mode="RGBA").save(OUT_DIR / "sign_sprite.png")
    Image.fromarray(title_clean, mode="RGB").save(OUT_DIR / "title_clean.png")

    chimney_px = [676.0, 162.0]
    chimney_depth = float(depth[int(chimney_px[1]) + 25, int(chimney_px[0])])
    write_title_fx_lua(w, h, sign_box, sign_pivot, sign_depth, anchors, chimney_px, chimney_depth)

    # Save visual channel inspection sheet in scripts/debug_out/
    DEBUG_DIR.mkdir(parents=True, exist_ok=True)
    tw, th = w // 4, h // 4
    ch_imgs = [
        ("env.R sky", mask_env[:, :, 0]),
        ("env.G moon", mask_env[:, :, 1]),
        ("env.B cobble", mask_env[:, :, 2]),
        ("env.A foliage", mask_env[:, :, 3]),
        ("fx.R void", mask_fx[:, :, 0]),
        ("fx.G glow", mask_fx[:, :, 1]),
        ("fx.B windows", mask_fx[:, :, 2]),
        ("fx.A rimlight", mask_fx[:, :, 3]),
    ]
    sheet = np.zeros((th * 2, tw * 4, 3), dtype=np.uint8)
    for idx, (label, ch) in enumerate(ch_imgs):
        r_i, c_i = divmod(idx, 4)
        tile = cv2.cvtColor(cv2.resize(ch, (tw, th), interpolation=cv2.INTER_AREA), cv2.COLOR_GRAY2BGR)
        cv2.putText(tile, label, (8, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 2, cv2.LINE_AA)
        sheet[r_i * th : (r_i + 1) * th, c_i * tw : (c_i + 1) * tw] = tile
    cv2.imwrite(str(DEBUG_DIR / "title_fx_channels.png"), sheet)

    print("[build_title_maps] Done! Generated 5 assets in assets/title_fx/:")
    for fname in ("depth.png", "mask_env.png", "mask_fx.png", "sign_sprite.png", "title_clean.png"):
        p = OUT_DIR / fname
        print(f"  - {p.relative_to(ROOT)} ({p.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
