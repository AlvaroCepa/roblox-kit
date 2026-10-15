# Junta imágenes en UNA: las referencias a la izquierda y las capturas de Studio a la derecha, a la misma altura
# y con su rótulo. La usa kit/captura.js; sirve igual a mano:
#   py -3 lado-a-lado.py salida.png --titulo "UI Hud" --refs ref1.png ref2.png --capturas cap1.png cap2.png
# Solo necesita Pillow (lo instala scripts/diagnostico.ps1).
import argparse

from PIL import Image, ImageDraw, ImageFont

ALTO = 420  # alto de cada imagen en la hoja
MARGEN = 12


def cargar(ruta):
    # «ruta#ancho,alto»: recorta desde arriba a la izquierda esa fracción (el marco de un dispositivo).
    recorte = None
    if "#" in ruta:
        ruta, fr = ruta.rsplit("#", 1)
        recorte = [float(x) for x in fr.split(",")]
    im = Image.open(ruta).convert("RGB")
    if recorte:
        im = im.crop((0, 0, max(1, round(im.width * recorte[0])), max(1, round(im.height * recorte[1]))))
    ancho = round(im.width * ALTO / im.height)
    return im.resize((ancho, ALTO), Image.LANCZOS)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("salida")
    p.add_argument("--titulo", default="")
    p.add_argument("--refs", nargs="*", default=[])
    p.add_argument("--capturas", nargs="*", default=[])
    a = p.parse_args()

    filas = []
    if a.refs:
        filas.append(("Referencia", [cargar(r) for r in a.refs]))
    filas.append(("Studio", [cargar(c) for c in a.capturas]))

    letra = ImageFont.load_default()
    rotulo = 22
    ancho = max(sum(im.width for im in ims) + MARGEN * (len(ims) + 1) for _, ims in filas)
    alto = rotulo + sum(ALTO + rotulo + MARGEN for _ in filas) + MARGEN
    hoja = Image.new("RGB", (ancho, alto), (32, 34, 40))
    dibujo = ImageDraw.Draw(hoja)
    dibujo.text((MARGEN, 4), a.titulo, fill=(255, 255, 255), font=letra)
    y = rotulo
    for nombre, ims in filas:
        dibujo.text((MARGEN, y + 4), nombre, fill=(200, 200, 200), font=letra)
        x = MARGEN
        for im in ims:
            hoja.paste(im, (x, y + rotulo))
            x += im.width + MARGEN
        y += ALTO + rotulo + MARGEN
    hoja.save(a.salida)


if __name__ == "__main__":
    main()
