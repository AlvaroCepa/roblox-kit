---
name: sonido
description: Cómo se ponen los sonidos y la música en los juegos de Roblox con roblox-kit (biblioteca de audio de Roblox primero, packs gratis de uso comercial después, 3 candidatos por sonido para que Álvaro elija de oído, sonidos como datos lanzados con Kit/Sounds en el cliente, canales música/efectos/interfaz, música por zona con fundidos). Úsala SIEMPRE que haya que añadir, cambiar o revisar sonidos, efectos de sonido, música, volúmenes o el botón de silenciar, aunque no se diga «sonido».
---

# Sonido

**Nada de cero y Claude no oye.** Claude elige por nombre, descripción y duración y pasa **3 candidatos por
sonido**; **Álvaro elige de oído**.

## De dónde salen
1. **La biblioteca de audio de Roblox** (Creator Store, audio con licencia de Roblox): miles de efectos y música,
   gratis para juegos, sin subir nada ni moderación. Se apuntan como `"library:<id>"` en `Data/Sounds.luau`.
   Búscalos con `search_asset` del MCP de Studio (tipo audio) o en la Creator Store.
2. Si falta algo, **packs gratuitos de uso libre** (uso comercial y sin atribución obligatoria): a
   `assets/sounds/` y `kit/subir-assets.ps1` (pregunta antes).
3. **IA casi nunca** (licencias no comerciales o hay que correrla en Kaggle): solo para un sonido muy concreto.
- **Pendiente, al empezar con el sonido por primera vez:** investigar a fondo los mejores packs gratuitos y
  preseleccionar unos cuantos (Álvaro lo pidió).

## Cómo se usa en el juego
- `src/shared/Data/Sounds.luau`: cada sonido con `asset`, `channel` (music, sfx, ui), `volume`, `pitch`,
  `variation` (± tono al azar, para que no canse) y `looped`.
- UNA línea, en el cliente (el servidor solo avisa por Zap): `Sounds.play("Coin", part, "epic")`.
- Música: `Sounds.music("Lobby")` funde con la anterior (nunca corta de golpe); `Sounds.music(nil)` silencio;
  `Sounds.setMusicMuted(true)` para el botón de silenciar la música (que tiene que haber).
- Estilo en `Data/Style.luau` (`sound`): tono, volumen de cada canal, tres niveles y el tiempo del fundido.
- Tope de copias del mismo sonido a la vez (`Style.sound.maxSame`): las que pasan, no suenan.

## Reglas
1. Efectos cortos (< 3 s) y sin bucle; la música, pocas pistas (una por zona o momento).
2. Nada de `Sound` dentro de modelos que se repiten (enemigos, mascotas): se reproduce desde el kit.
3. Ids por nombre o `library:<id>`: `comprobar` vigila los ids sueltos y que los canales existan.
4. Volumen parecido entre sonidos y sin silencio al principio: hoy se comprueba **de oído** (Álvaro). Medirlo con
   un script queda para cuando haya packs subidos (`assets/sounds/`).
