"""스프라이트 래스터라이저 (tools/generate_sprites.py 가 사용).

모든 도형은 다각형 채우기 하나로 환원된다. 좌표는 게임의 절차적 도형(ui/ItemShapes.lua)과 같은
정규화 좌표(-0.5 ~ 0.5, y 아래쪽)라서 오염 얼룩·결함 표식 위치가 스프라이트에서도 그대로 맞는다.
  - Pillow 가 설치되어 있으면: PIL 로 4배 슈퍼샘플링 후 축소, PNG 저장도 PIL
  - 없으면: 순수 파이썬 스캔라인 채우기(3배 슈퍼샘플링) + zlib/struct PNG 인코더
stylize() 는 두 경로 공통 후처리: 어두운 외곽선, 좌상단 하이라이트·우하단 그림자, 미세한 질감.
"""

import math
import random
import struct
import zlib

try:
    from PIL import Image, ImageDraw
    HAVE_PIL = True
except ImportError:     # Pillow 없음 → 표준 라이브러리 경로
    HAVE_PIL = False

SIZE = 128
ART_SCALE = 0.94        # 외곽선이 잘리지 않도록 가장자리에 여백을 둔다
OUTLINE = (20, 14, 26)
OUTLINE_RADIUS = 3


def rgba8(color):
    alpha = color[3] if len(color) > 3 else 1.0
    return tuple(max(0, min(255, int(round(v * 255)))) for v in (color[0], color[1], color[2], alpha))


class PilSurface:
    SS = 4

    def __init__(self, size):
        self.size = size
        self.image = Image.new("RGBA", (size * self.SS, size * self.SS), (0, 0, 0, 0))

    def polygon(self, points, rgba):
        mask = Image.new("L", self.image.size, 0)
        ImageDraw.Draw(mask).polygon([(x * self.SS, y * self.SS) for x, y in points], fill=rgba[3])
        layer = Image.new("RGBA", self.image.size, rgba[:3] + (0,))
        layer.putalpha(mask)
        self.image.alpha_composite(layer)

    def pixels(self):
        return bytearray(self.image.resize((self.size, self.size), Image.LANCZOS).tobytes())


class PureSurface:
    """Pillow 없이 동작하는 스캔라인 래스터라이저 (짝-홀 규칙, 'over' 합성)."""
    SS = 3

    def __init__(self, size):
        self.size = size
        self.n = size * self.SS
        self.buf = bytearray(self.n * self.n * 4)

    def polygon(self, points, rgba):
        n, ss = self.n, self.SS
        pts = [(x * ss, y * ss) for x, y in points]
        top = max(0, int(math.floor(min(p[1] for p in pts))))
        bottom = min(n - 1, int(math.ceil(max(p[1] for p in pts))))
        for y in range(top, bottom + 1):
            yc = y + 0.5
            crossings = []
            for i, (ax, ay) in enumerate(pts):
                bx, by = pts[(i + 1) % len(pts)]
                if (ay <= yc < by) or (by <= yc < ay):
                    crossings.append(ax + (yc - ay) * (bx - ax) / (by - ay))
            crossings.sort()
            for k in range(0, len(crossings) - 1, 2):
                x0 = max(0, int(math.ceil(crossings[k] - 0.5)))
                x1 = min(n - 1, int(math.floor(crossings[k + 1] - 0.5)))
                if x1 >= x0:
                    self._span(y, x0, x1, rgba)

    def _span(self, y, x0, x1, rgba):
        r, g, b, a = rgba
        base = (y * self.n + x0) * 4
        end = base + (x1 - x0 + 1) * 4
        buf = self.buf
        if a >= 255:
            buf[base:end] = bytes((r, g, b, 255)) * (x1 - x0 + 1)
            return
        sa = a / 255.0
        for i in range(base, end, 4):
            da = buf[i + 3] / 255.0
            oa = sa + da * (1.0 - sa)
            if oa > 0:
                keep = da * (1.0 - sa)
                buf[i] = int((r * sa + buf[i] * keep) / oa + 0.5)
                buf[i + 1] = int((g * sa + buf[i + 1] * keep) / oa + 0.5)
                buf[i + 2] = int((b * sa + buf[i + 2] * keep) / oa + 0.5)
                buf[i + 3] = int(oa * 255 + 0.5)

    def pixels(self):
        """알파를 미리 곱해 SS x SS 상자 평균으로 축소한다."""
        size, ss, n, buf = self.size, self.SS, self.n, self.buf
        out = bytearray(size * size * 4)
        samples = ss * ss
        for y in range(size):
            for x in range(size):
                r = g = b = a = 0
                for sy in range(ss):
                    i = ((y * ss + sy) * n + x * ss) * 4
                    for _ in range(ss):
                        alpha = buf[i + 3]
                        r += buf[i] * alpha
                        g += buf[i + 1] * alpha
                        b += buf[i + 2] * alpha
                        a += alpha
                        i += 4
                if a > 0:
                    o = (y * size + x) * 4
                    out[o], out[o + 1], out[o + 2] = int(r / a + 0.5), int(g / a + 0.5), int(b / a + 0.5)
                    out[o + 3] = int(a / samples + 0.5)
        return out


class Canvas:
    """정규화 좌표 도형 → 다각형. transform() 으로 이동·확대를 중첩할 수 있다."""

    def __init__(self, size=SIZE, use_pil=True):
        self.size = size
        self.surface = PilSurface(size) if (HAVE_PIL and use_pil) else PureSurface(size)
        self._stack = [(0.0, 0.0, 1.0)]

    def push(self, dx, dy, scale):
        ox, oy, s = self._stack[-1]
        self._stack.append((ox + dx * s, oy + dy * s, s * scale))

    def pop(self):
        self._stack.pop()

    def _px(self, x, y):
        ox, oy, s = self._stack[-1]
        unit = self.size * ART_SCALE
        return (self.size / 2 + (ox + x * s) * unit, self.size / 2 + (oy + y * s) * unit)

    def polygon(self, points, color):
        self.surface.polygon([self._px(x, y) for x, y in points], rgba8(color))

    def poly(self, color, *coords):
        self.polygon(list(zip(coords[0::2], coords[1::2])), color)

    def ellipse(self, cx, cy, rx, ry, color, segments=44):
        self.polygon([(cx + math.cos(i / segments * math.tau) * rx, cy + math.sin(i / segments * math.tau) * ry)
                      for i in range(segments)], color)

    def circle(self, cx, cy, r, color):
        self.ellipse(cx, cy, r, r, color)

    def rect(self, x, y, w, h, color, radius=0.0):
        if radius <= 0:
            self.poly(color, x, y, x + w, y, x + w, y + h, x, y + h)
            return
        radius = min(radius, w / 2, h / 2)
        points = []
        corners = ((x + w - radius, y + radius, -90), (x + w - radius, y + h - radius, 0),
                   (x + radius, y + h - radius, 90), (x + radius, y + radius, 180))
        for cx, cy, start in corners:
            for i in range(7):
                angle = math.radians(start + i * 15)
                points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
        self.polygon(points, color)

    def line(self, points, width, color):
        """둥근 이음매의 굵은 꺾은선 (불투명 색 전용)."""
        half = width / 2
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            length = math.hypot(bx - ax, by - ay) or 1e-9
            nx, ny = -(by - ay) / length * half, (bx - ax) / length * half
            self.polygon([(ax + nx, ay + ny), (bx + nx, by + ny), (bx - nx, by - ny), (ax - nx, ay - ny)], color)
        for x, y in points:
            self.ellipse(x, y, half, half, color, 16)

    def arc(self, cx, cy, r, start, end, width, color, segments=20):
        self.line([(cx + math.cos(start + (end - start) * i / segments) * r,
                    cy + math.sin(start + (end - start) * i / segments) * r) for i in range(segments + 1)], width, color)

    def pixels(self):
        return self.surface.pixels()


def stylize(pixels, size, seed):
    """외곽선 + 입체 음영(좌상단 하이라이트 / 우하단 그림자) + 미세한 질감. 새 bytearray 반환."""
    rng = random.Random(seed)
    alpha = [pixels[i * 4 + 3] for i in range(size * size)]
    shaded = bytearray(pixels)
    for y in range(size):
        for x in range(size):
            i = y * size + x
            if alpha[i] == 0:
                continue
            light = 1.10 - 0.28 * (x + y) / (2.0 * size) + rng.uniform(-0.035, 0.035)
            if x < 2 or y < 2 or alpha[i - 2 * size - 2] < 128:
                light += 0.22
            if x >= size - 2 or y >= size - 2 or alpha[i + 2 * size + 2] < 128:
                light -= 0.25
            for c in range(3):
                shaded[i * 4 + c] = max(0, min(255, int(pixels[i * 4 + c] * light + 0.5)))

    reach = OUTLINE_RADIUS
    offsets = [(dx, dy) for dx in range(-reach, reach + 1) for dy in range(-reach, reach + 1)
               if dx * dx + dy * dy <= reach * reach + 0.5]
    out = bytearray(shaded)
    for y in range(size):
        for x in range(size):
            i = y * size + x
            own = alpha[i]
            if own >= 250:
                continue
            around = own
            for dx, dy in offsets:
                nx, ny = x + dx, y + dy
                if 0 <= nx < size and 0 <= ny < size and alpha[ny * size + nx] > around:
                    around = alpha[ny * size + nx]
            if around <= own:
                continue
            sa, oa = own / 255.0, around / 255.0
            total = sa + oa * (1.0 - sa)
            for c in range(3):
                out[i * 4 + c] = int((shaded[i * 4 + c] * sa + OUTLINE[c] * oa * (1.0 - sa)) / total + 0.5)
            out[i * 4 + 3] = int(total * 255 + 0.5)
    return out


def encode_png(size, pixels):
    """표준 라이브러리만으로 RGBA 8비트 PNG 를 만든다."""
    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    row = size * 4
    raw = b"".join(b"\x00" + bytes(pixels[y * row:(y + 1) * row]) for y in range(size))
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def save_png(path, size, pixels, use_pil=True):
    if HAVE_PIL and use_pil:
        Image.frombytes("RGBA", (size, size), bytes(pixels)).save(path, optimize=True)
    else:
        with open(path, "wb") as out:
            out.write(encode_png(size, pixels))
