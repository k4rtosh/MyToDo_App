"""Иконки приложения и favicon: белый фон + зелёный кружок в мягком кольце.

Повторяет логотип из интерфейса (.brand .dot): круг #0f766e в кольце #e7f4f1.
Запуск:  python tools/make-icons.py
Создаёт: icons/icon-192.png, icons/icon-512.png, icons/apple-touch-icon.png,
         icons/favicon.svg, icons/favicon-16.png, icons/favicon-32.png, favicon.ico
"""

import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
ICONS = os.path.join(ROOT, "icons")

ACC = (15, 118, 110)      # #0f766e — зелёный кружок
SOFT = (231, 244, 241)    # #e7f4f1 — мягкое кольцо
WHITE = (255, 255, 255)   # фон

OUTER = 0.86              # диаметр кольца относительно стороны
INNER = 0.56              # диаметр кружка относительно стороны
# на 16 px кольцо почти не видно, а кружок мельчает — для мелкого размера пропорции крупнее
SMALL = {16: (0.92, 0.63)}
SUPERSAMPLE = 8           # рисуем крупно и уменьшаем: так края гладкие

SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" role="img" aria-label="Задачи">
  <rect width="64" height="64" fill="#ffffff"/>
  <circle cx="32" cy="32" r="{outer:.2f}" fill="#e7f4f1"/>
  <circle cx="32" cy="32" r="{inner:.2f}" fill="#0f766e"/>
</svg>
""".format(outer=64 * OUTER / 2, inner=64 * INNER / 2)


def render(size: int) -> Image.Image:
    outer, inner = SMALL.get(size, (OUTER, INNER))
    canvas = size * SUPERSAMPLE
    img = Image.new("RGB", (canvas, canvas), WHITE)
    draw = ImageDraw.Draw(img)
    center = canvas / 2
    r_outer = canvas * outer / 2
    r_inner = canvas * inner / 2

    draw.ellipse(
        [center - r_outer, center - r_outer, center + r_outer, center + r_outer],
        fill=SOFT,
    )
    draw.ellipse(
        [center - r_inner, center - r_inner, center + r_inner, center + r_inner],
        fill=ACC,
    )
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    os.makedirs(ICONS, exist_ok=True)

    with open(os.path.join(ICONS, "favicon.svg"), "w", encoding="utf-8") as f:
        f.write(SVG)

    for size, name in ((16, "favicon-16.png"), (32, "favicon-32.png"),
                       (180, "apple-touch-icon.png"), (192, "icon-192.png"),
                       (512, "icon-512.png")):
        render(size).save(os.path.join(ICONS, name))

    # многоразмерный .ico: 16/32/48 — закладки, старые браузеры, ярлык Windows
    render(256).save(os.path.join(ROOT, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])

    print("иконки готовы: icon-192, icon-512, apple-touch-icon, favicon (svg/16/32/ico)")


if __name__ == "__main__":
    main()
