---
name: ui
description: Cómo se hace la UI de los juegos de Roblox con roblox-kit (pantallas en código con el constructor Kit/UI, hoja de estilo, botones de imagen en 9-slice generados, iconos, Asphalt, comprobador de UI y capturas al lado de las referencias). Úsala SIEMPRE que haya que crear, cambiar, revisar o arreglar cualquier interfaz de un juego (pantallas, HUD, botones, tiendas, inventarios, menús, avisos, iconos, la hoja de estilo), aunque no se diga «UI», y también para pasar algo de Figma a Roblox.
---

# UI

**Requisito de Álvaro: tiene que quedar PROFESIONAL.** Roblox solo dibuja rectángulos planos; lo que hace que un
botón parezca de juego bueno (brillo, labio 3D, sombra, contorno con relieve) sale de **imágenes**. Por eso los
cuerpos de botones y paneles son imágenes generadas desde la hoja de estilo, y lo nativo solo coloca y pone texto.

## Dónde está cada cosa (en el juego)
- `src/shared/Data/Style.luau`: la hoja de estilo (paleta, fuente, un solo contorno, esquinas, cuerpo de los
  botones, tiempos). **Todo valor visual sale de aquí.** La base es TEMPORAL (Steal a Brainrot) hasta que Álvaro
  elija 3-5 capturas de referencia: entonces se rehace desde ellas (ver `referencias/estilo.md`).
- `src/client/UI/Style.luau`: funciones de estilo del juego (`depthButton`, `panel`, `label`). Todos los botones
  salen de ahí, iguales.
- `src/client/UI/<Pantalla>.luau`: una pantalla por archivo, con `create(parent)`, `render(state)`, `sample`
  (datos del peor caso) y, si siempre se ve, `hud = true`. Ejemplo: `Hud.luau`.
- Kit (copias del plugin, no se editan): `Kit/UI` (constructor), `Kit/Screens` (gestor), `Kit/List` (listas),
  `Kit/UIMotion` (animaciones), `Kit/Theme` (colores y fuente), `Kit/Asset` (ids por nombre), `Kit/UICheck`.
- Textos visibles: `src/shared/Data/Texts.luau`, en inglés. Formatos (1.2T, 3:05): `src/shared/Rules/Format.luau`.
- Imágenes: `assets/ui/` (las del kit, en `assets/ui/kit/`; iconos en `assets/ui/icons/`).

## Reglas (con su porqué)
1. **Todo en Scale, Offset = 0.** Con Offset la UI se rompe en otras pantallas. `Kit/UI` da error si lo ve.
2. **AnchorPoint centrado** (0.5, 0.5); otro solo con `AnchorReason` (HUD pegado a un borde, barras que se
   llenan, listas que crecen hacia un lado). Con ancla en una esquina, al animar o cambiar de pantalla se descoloca.
3. **Un solo grosor de contorno** (`Style.ui.stroke`, UIStroke en ScaledSize). Grosores distintos delatan a la IA.
4. **Nada de botones planos de un color, emojis como iconos ni valores fuera de la hoja.** Lo vigila `comprobar`.
5. **Textos de `Data/Texts`, colores con `Theme.color("nombre")`, fuente con `Theme.font()`.** Así se cambia
   el juego entero desde un sitio y se puede traducir.
6. **Ids por nombre** (`Asset.get("ui/icons/coin")`), nunca `rbxassetid://` en el código.
7. **La UI nunca decide.** El botón pide por Zap, el servidor comprueba y responde, la UI enseña el resultado.
   Mientras espera, el botón no responde (sin compras dobles). Las pantallas no llaman a la red: el sistema que
   las usa les pasa `actions` (mira `Systems/Hud.luau`). Así el comprobador las puede montar en modo edición.
8. **`render(state)` pone TODOS los valores** y se puede llamar siempre: nada de actualizaciones sueltas que dejan
   textos desfasados.
9. **Botones con `Activated`** (ratón, toque y mando).
10. **Sin `UIScale` ni `CanvasGroup`**: UIScale descuadra los contornos en ScaledSize; CanvasGroup emborrona.
11. **Iconos siempre imagen, nunca `ViewportFrame`** (pesa en móvil). Máximo 1024 px; iconos de 256-512.

## Pasos para una pantalla nueva
1. **Ficha corta** en el bloque (qué lleva, qué hace cada botón, de dónde sale cada número). Textos a `Data/Texts`.
2. **Código**: copia la forma de `Hud.luau`. Construye con `UI.new` y `Style.*`; listas con `List`; se abre con
   `Screens.open("Nombre", state)`. Pon `sample` con el peor caso (nombre más largo, 1.2T, 50 objetos).
3. **Imágenes que falten**: los cuerpos se generan (`lune run <kit>/kit/ui-generar.luau`, tras cambiar la hoja);
   los iconos, ver `referencias/imagenes.md`. Para verlos en Studio sin subirlos: `asphalt sync studio` (ese
   `src/shared/Assets` no va a git).
4. **Comprobador en Studio** (modo Edit, Rojo conectado): execute_luau
   `return require(game.ReplicatedStorage.Shared.Kit.UICheck).run()`. Una línea si va bien; si no, arregla cada
   problema y repite. El hook de Stop lo pide si cambió la UI desde la última pasada buena.
5. **Capturas al lado de las referencias**, en una sola imagen, para Álvaro:
   `node <kit>/kit/captura.js ui <Pantalla> todos --ref <capturas de referencia o concepto>` (PC y móviles).
   Mira la imagen con Read antes de enseñarla. **Lo juzga Álvaro**; tú solo compruebas que respeta la hoja.
   Si cambia algo a mano en Studio, lee los valores con `inspect_instance` y pásalos al archivo.
6. **Subir** las imágenes nuevas al grupo cuando Álvaro las apruebe:
   `powershell -NoProfile -ExecutionPolicy Bypass -File <kit>/kit/subir-assets.ps1` (pregunta antes; avisa de la
   moderación). `asphalt.lock.toml` y `src/shared/Assets/` van en el commit.

## Más detalle (léelo cuando toque)
- `referencias/estilo.md`: cómo sacar la hoja de estilo de 3-5 capturas y qué es cada número.
- `referencias/imagenes.md`: iconos con Nano Banana + rembg, iconos de modelos 3D, tamaños, moderación.
- `referencias/reglas-scale.md`: fórmulas px → Scale, nativo frente a imagen, 9-slice, tabla de propiedades,
  rendimiento y errores típicos (de `figma-to-roblox-ui`).
- `referencias/figma.md`: solo si Álvaro quiere colocar algo él en Figma (opcional; tope de llamadas en el plan gratis).

Juegos antiguos (Steal an Egg) tienen la UI hecha en Studio: allí se sigue su forma hasta que se adapten.
