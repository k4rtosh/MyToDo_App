"""Генерация иконок PWA без внешних ассетов: скруглённый квадрат + галочка."""
from PIL import Image, ImageDraw

ACCENT = (15, 118, 110, 255)   # #0f766e
WHITE = (255, 255, 255, 255)


def make_icon(size: int, out_path: str) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    pad = int(size * 0.07)
    radius = int(size * 0.22)
    d.rounded_rectangle([pad, pad, size - pad, size - pad], radius=radius, fill=ACCENT)

    w = max(2, int(size * 0.085))
    pts = [
        (int(size * 0.29), int(size * 0.52)),
        (int(size * 0.44), int(size * 0.67)),
        (int(size * 0.72), int(size * 0.35)),
    ]
    d.line(pts, fill=WHITE, width=w, joint="curve")
    # скругления на концах
    r = w // 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)

    img.save(out_path, "PNG")


if __name__ == "__main__":
    import os
    base = os.path.join(os.path.dirname(__file__), "..", "icons")
    os.makedirs(base, exist_ok=True)
    make_icon(192, os.path.join(base, "icon-192.png"))
    make_icon(512, os.path.join(base, "icon-512.png"))
    make_icon(180, os.path.join(base, "apple-touch-icon.png"))
    print("иконки готовы: icon-192.png, icon-512.png, apple-touch-icon.png")
