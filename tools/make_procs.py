"""Dibuja las texturas de los procs del paladín.

- light_glow.tga y light_core.tga: 16 fotogramas (4x4 de 64x256) de luz que cae: trazos finos y
  chispas que bajan, para una animación FlipBook que se repite sin corte (en una vuelta cada trazo
  baja una o dos alturas enteras). Infusión de Luz. El brillo y el núcleo van aparte para teñir el
  brillo con tu color y dejar el núcleo casi blanco.
- rise_glow.tga y rise_core.tga: la misma luz, subiendo (cada fotograma al revés). Reckoning.
- halo_glow.tga y halo_core.tga: 16 fotogramas (4x4 de 256x128) de un círculo sagrado visto en el
  suelo: ocho runas (un arco con una cruz pequeña) girando un octavo de vuelta, así la vuelta
  empalma. Venganza y Redoubt a los pies, Favor divino pequeño sobre la cabeza.
- halo_rev_glow.tga y halo_rev_core.tga: el mismo círculo girando al otro lado (cada fotograma en
  espejo). Shieldsworn, más grande, alrededor del de los pies.
- halo_base.tga: el círculo quieto: dos círculos finos y cuatro cruces.
- shield_glow.tga y shield_core.tga: un escudo pequeño con una cruz, quieto. Iron Creed.
- proc_aura.tga: un brillo alargado detrás de cada columna de luz.
- proc_spot.tga: un brillo redondo para el destello del círculo y los avisos de Martillo y Exorcismo.

Todo en blanco: el color lo pone el juego (SetVertexColor) y la transparencia es la intensidad.
Uso: python -I make_procs.py <carpeta media del addon>
Necesita: pip install pillow
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

SS = 4  # se dibuja grande y se reduce para suavizar bordes
COLS, ROWS = 4, 4
FRAMES = COLS * ROWS

LFW, LFH = 64, 256  # un fotograma de la luz: estrecho
RFW, RFH = 256, 128  # un fotograma del círculo
SQUASH = 0.38  # un círculo en el suelo, visto desde la cámara: más ancho que alto
RX = 106  # radio del círculo en píxeles finales, a lo ancho


def stretch(img, gain):
    """Sube la intensidad sin pasar de 255"""
    return img.point(lambda v: min(255, int(v * gain)))


def white(alpha):
    img = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    img.putalpha(alpha)
    return img


def brush(d, pts, widths, power):
    """Una línea de grosor variable: tramos cortos con las puntas redondas"""
    fill = int(255 * power)
    for (ax, ay), (bx, by), w in zip(pts, pts[1:], widths):
        if w <= 0.2:
            continue
        d.line((ax, ay, bx, by), fill=fill, width=max(1, round(w)))
        r = w / 2
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=fill)


# ---------------------------------------------------------------- Luz que cae

def motes(seed):
    """Los trazos de una columna: dónde, lo largos, lo gruesos y lo rápidos que caen"""
    rng = random.Random(seed)
    out = []
    for i in range(9):
        out.append(dict(
            x=rng.uniform(-14, 14),
            length=rng.uniform(26, 84),
            width=rng.uniform(1.2, 2.6),
            laps=1 if i % 3 else 2,  # alturas enteras por vuelta: la animación empalma
            phase=rng.uniform(0, 1),
            power=rng.uniform(0.5, 1.0),
            spark=i % 2 == 0,  # algunos llevan una chispa en la cabeza
        ))
    return out


def light_layer(ms, t, scale, power=1.0):
    """Los trazos en el momento t (0 a 1 de la vuelta), con el grosor por scale"""
    w, h = LFW * SS, LFH * SS
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for m in ms:
        head = ((m["phase"] + m["laps"] * t) % 1.0) * h  # cae: la y sube con el tiempo
        length = m["length"] * SS
        x = w / 2 + m["x"] * SS
        for shift in (-h, 0, h):  # el que sale por abajo entra por arriba
            bottom = head + shift
            if bottom < 0 or bottom - length > h:
                continue
            n = 16
            pts, widths = [], []
            for k in range(n + 1):
                s = k / n  # 0 en la cola (arriba), 1 en la cabeza (abajo)
                pts.append((x, bottom - length + s * length))
                widths.append(m["width"] * scale * SS * (0.15 + 0.85 * s ** 1.5))
            brush(d, pts, widths[1:], m["power"] * power)
            if m["spark"]:
                r = m["width"] * scale * SS * 1.6
                fill = int(255 * min(1.0, m["power"] * power * 1.1))
                d.ellipse((x - r, bottom - r, x + r, bottom + r), fill=fill)
    return img


def fade_ends(img, edge=0.2):
    """Se apaga suave arriba y abajo, para que la luz aparezca y se vaya sin corte"""
    mask = Image.new("L", (1, img.size[1]))
    for y in range(img.size[1]):
        t = y / (img.size[1] - 1)
        e = min(t, 1 - t) / edge
        mask.putpixel((0, y), int(255 * min(1.0, e) ** 1.6))
    return ImageChops.multiply(img, mask.resize(img.size))


def light_frame(ms, t):
    glow = ImageChops.add(stretch(light_layer(ms, t, 4.0).filter(ImageFilter.GaussianBlur(4 * SS)), 2.4),
                          stretch(light_layer(ms, t, 2.2).filter(ImageFilter.GaussianBlur(1.8 * SS)), 1.4))
    core = ImageChops.add(light_layer(ms, t, 1.0).filter(ImageFilter.GaussianBlur(0.3 * SS)),
                          light_layer(ms, t, 1.9, 0.45).filter(ImageFilter.GaussianBlur(0.8 * SS)))
    return [fade_ends(layer).resize((LFW, LFH), Image.LANCZOS) for layer in (glow, core)]


def light_sheets():
    ms = motes(7070)
    glow_sheet = Image.new("L", (LFW * COLS, LFH * ROWS), 0)
    core_sheet = Image.new("L", (LFW * COLS, LFH * ROWS), 0)
    for n in range(FRAMES):
        glow, core = light_frame(ms, n / FRAMES)
        x, y = (n % COLS) * LFW, (n // COLS) * LFH
        glow_sheet.paste(glow, (x, y))
        core_sheet.paste(core, (x, y))
    return white(glow_sheet), white(core_sheet)


# ---------------------------------------------------------------- Círculo sagrado

def ground(angle, radius):
    """Un punto del círculo del suelo, visto desde la cámara (y hacia abajo)"""
    return (RFW / 2 + RX * radius * math.cos(angle)) * SS, (RFH / 2 + RX * SQUASH * radius * math.sin(angle)) * SS


def depth(angle):
    """Lo de delante (abajo) un poco más grueso y fuerte que lo de detrás"""
    return 0.78 + 0.22 * (1 + math.sin(angle))


def arc(d, a0, a1, radius, width, power, steps=24):
    pts = [ground(a0 + (a1 - a0) * k / steps, radius) for k in range(steps + 1)]
    mids = [a0 + (a1 - a0) * (k + 0.5) / steps for k in range(steps)]
    widths = [width * SS * depth(a) for a in mids]
    fill_power = power * sum(depth(a) for a in mids) / len(mids) / 1.22
    brush(d, pts, widths, min(1.0, fill_power))


def cross(d, angle, radius, size, width, power):
    """Una cruz pequeña tumbada en el suelo, en ese punto del círculo"""
    cx, cy = ground(angle, radius)
    w = max(1, round(width * SS * depth(angle)))
    fill = int(255 * min(1.0, power))
    sx, sy = size * SS, size * SS * SQUASH * 1.6
    d.line((cx - sx, cy, cx + sx, cy), fill=fill, width=w)
    d.line((cx, cy - sy * 1.3, cx, cy + sy), fill=fill, width=w)


def runes_layer(turn, scale, power=1.0):
    """Ocho runas en el borde, giradas turn (0 a 1 de un octavo de vuelta)"""
    img = Image.new("L", (RFW * SS, RFH * SS), 0)
    d = ImageDraw.Draw(img)
    step = math.tau / 8
    for i in range(8):
        a0 = i * step + turn * step
        arc(d, a0, a0 + step * 0.42, 1.0, 2.2 * scale, power)
        cross(d, a0 + step * 0.71, 1.0, 4.2, 1.3 * scale, power * 0.9)
    return img


def halo_frame(turn):
    glow = ImageChops.add(stretch(runes_layer(turn, 3.2).filter(ImageFilter.GaussianBlur(4 * SS)), 2.2),
                          stretch(runes_layer(turn, 1.8).filter(ImageFilter.GaussianBlur(1.4 * SS)), 1.3))
    core = ImageChops.add(runes_layer(turn, 1.0).filter(ImageFilter.GaussianBlur(0.3 * SS)),
                          runes_layer(turn, 1.7, 0.4).filter(ImageFilter.GaussianBlur(0.8 * SS)))
    return [layer.resize((RFW, RFH), Image.LANCZOS) for layer in (glow, core)]


def halo_sheets():
    glow_sheet = Image.new("L", (RFW * COLS, RFH * ROWS), 0)
    core_sheet = Image.new("L", (RFW * COLS, RFH * ROWS), 0)
    for n in range(FRAMES):
        glow, core = halo_frame(n / FRAMES)
        x, y = (n % COLS) * RFW, (n // COLS) * RFH
        glow_sheet.paste(glow, (x, y))
        core_sheet.paste(core, (x, y))
    return white(glow_sheet), white(core_sheet)


def halo_base():
    """El círculo quieto: dos círculos finos por dentro y cuatro cruces entre ellos"""
    def layer(scale, power=1.0):
        img = Image.new("L", (RFW * SS, RFH * SS), 0)
        d = ImageDraw.Draw(img)
        arc(d, 0, math.tau, 0.56, 1.1 * scale, power * 0.8, 120)
        arc(d, 0, math.tau, 0.84, 0.8 * scale, power * 0.6, 120)
        for i in range(4):
            cross(d, i * math.tau / 4 + math.tau / 8, 0.7, 5.0, 1.6 * scale, power)
        return img
    glow = stretch(layer(3.0).filter(ImageFilter.GaussianBlur(3.5 * SS)), 1.6)
    core = layer(1.0).filter(ImageFilter.GaussianBlur(0.3 * SS))
    return white(ImageChops.add(glow, core).resize((RFW, RFH), Image.LANCZOS))


def each_frame(sheet, fw, fh, turn):
    """Cada fotograma de una hoja, dado la vuelta (turn: ImageOps.flip o ImageOps.mirror)"""
    out = Image.new(sheet.mode, sheet.size, 0)
    for n in range(FRAMES):
        box = ((n % COLS) * fw, (n // COLS) * fh, (n % COLS + 1) * fw, (n // COLS + 1) * fh)
        out.paste(turn(sheet.crop(box)), box[:2])
    return out


# ---------------------------------------------------------------- Escudo

SW, SH = 96, 112  # el escudo, en píxeles finales


def shield_layer(scale, power=1.0):
    """El contorno de un escudo de cometa con una cruz dentro"""
    img = Image.new("L", (SW * SS, SH * SS), 0)
    d = ImageDraw.Draw(img)
    w, h = SW * SS, SH * SS
    top, mid, bottom = h * 0.12, h * 0.5, h * 0.9
    left, right, cx = w * 0.2, w * 0.8, w / 2
    pts = [(left, top), (right, top), (right, mid)]
    # La punta de abajo: una curva de cada lado
    for k in range(1, 13):
        s = k / 12
        pts.append((right + (cx - right) * s, mid + (bottom - mid) * (s ** 0.8)))
    for k in range(1, 13):
        s = k / 12
        pts.append((cx + (left - cx) * s, bottom + (mid - bottom) * s ** 1.25))
    pts.append((left, top))
    brush(d, pts, [2.2 * scale * SS] * len(pts), power)
    # La cruz
    fill, width = int(255 * power * 0.9), max(1, round(1.8 * scale * SS))
    d.line((cx, top + h * 0.1, cx, mid + h * 0.22), fill=fill, width=width)
    d.line((left + w * 0.12, top + h * 0.26, right - w * 0.12, top + h * 0.26), fill=fill, width=width)
    return img


def shield_textures():
    glow = ImageChops.add(stretch(shield_layer(3.2).filter(ImageFilter.GaussianBlur(4 * SS)), 2.0),
                          stretch(shield_layer(1.8).filter(ImageFilter.GaussianBlur(1.4 * SS)), 1.2))
    core = shield_layer(1.0).filter(ImageFilter.GaussianBlur(0.3 * SS))
    return [white(layer.resize((SW, SH), Image.LANCZOS)) for layer in (glow, core)]


# ---------------------------------------------------------------- Brillos

def soft(w, h, sx, sy):
    """Una campana suave que llega a cero en los bordes"""
    alpha = Image.new("L", (w, h))
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1
            bell = math.exp(-(dx * dx) / sx - (dy * dy) / sy)
            edge = max(0.0, 1 - dx * dx) * max(0.0, 1 - dy * dy)
            alpha.putpixel((x, y), int(255 * bell * edge))
    return white(alpha)


if __name__ == "__main__":
    media = Path(sys.argv[1])
    glow, core = light_sheets()
    glow.save(media / "light_glow.tga")
    core.save(media / "light_core.tga")
    each_frame(glow, LFW, LFH, ImageOps.flip).save(media / "rise_glow.tga")
    each_frame(core, LFW, LFH, ImageOps.flip).save(media / "rise_core.tga")
    glow, core = halo_sheets()
    glow.save(media / "halo_glow.tga")
    core.save(media / "halo_core.tga")
    each_frame(glow, RFW, RFH, ImageOps.mirror).save(media / "halo_rev_glow.tga")
    each_frame(core, RFW, RFH, ImageOps.mirror).save(media / "halo_rev_core.tga")
    halo_base().save(media / "halo_base.tga")
    glow, core = shield_textures()
    glow.save(media / "shield_glow.tga")
    core.save(media / "shield_core.tga")
    soft(64, 256, 0.16, 0.3).save(media / "proc_aura.tga")
    soft(128, 128, 0.22, 0.22).save(media / "proc_spot.tga")
    print("light, rise, halo, halo_rev, halo_base, shield, proc_aura, proc_spot")
