# Figma (opcional)

> Adaptado de la skill `figma-to-roblox-ui` (licencia MIT, © 2026 Xtrair). En los juegos de roblox-kit
> el constructor `Kit/UI` ya aplica las reglas duras (Scale, ancla, ScaledSize, texto escalado) y el
> comprobador `Kit/UICheck` hace lo del validador; esto queda como referencia de cómo y por qué.

Figma ya no está en el flujo normal: la UI se hace en código desde la hoja de estilo. Sirve cuando Álvaro
quiere colocar algo él visualmente desde cero. El plan gratis tiene tope de llamadas al MCP (se acabó en
Protect the Pyramid). Lo que se saque de Figma se pasa a código con `Kit/UI` y las funciones de estilo.

## 1. Prepare the Figma file (before export)

- The root frame is the reference screen. Use **1920×1080** (PC) or **1280×720**; check mobile at 844×390. Remember the root size — all Scale values derive from it.
- Anything that becomes a UI object must be a **Frame**, not a Group: groups have no bounds or clipping of their own, and plugins/math break on them.
- Auto Layout → becomes `UIListLayout` + `UIPadding`. Gap and padding are converted to Scale.
- Layer names = instance names in Roblox (Latin, no spaces: `ShopPanel`, `BuyButton`). Hint prefixes: `btn_` → ImageButton/TextButton, `scroll_` → ScrollingFrame, `img_` → ImageLabel (export as image).
- Fonts: pick ones available in Roblox (Font/FontFace: Gotham/Montserrat, Fredoka One, Luckiest Guy, Bangers, Source Sans, etc.). Otherwise that text must be rasterized.
- Before exporting, sort every layer into **native** or **image** using section 2.

## 3. Pull data from Figma

Through the Figma MCP (load any Figma skill the server requires first):
1. `get_metadata` on the root nodeId → tree, types, x/y/w/h, names.
2. `get_design_context` → fills, strokes (weight + align), radii, effects, fonts, auto layout.
3. `get_screenshot` of the root → reference for comparison.
4. `download_assets` for every layer marked as **image** in section 2.

Figma coordinates are absolute → convert them to coordinates **relative to the direct parent** before computing Scale.

## 7. Build order in Studio

1. `ScreenGui` in StarterGui: `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`, `IgnoreGuiInset` as in the mockup (usually true for full-screen, false for HUD), `ScreenInsets = CoreUISafeInsets` for mobile.
2. Build the tree top-down in one Luau script (through `execute_luau` in the Roblox Studio MCP) using the helpers below, so Offset physically can't appear.
3. Containers + layouts first, then native visuals (Corner/Stroke/Gradient/Shadow), then images, then text on top.
4. Buttons: hover/press animations with TweenService on `Size` (Scale). With AnchorPoint (0.5, 0.5) the button grows and shrinks evenly around its center. Do **not** use `UIScale`: it mis-scales UIStrokes in ScaledSize mode (known bug, March 2026).

### Helpers (Luau)

```lua
local function S(x, y) return UDim2.fromScale(x, y) end
local function r4(n) return math.floor(n * 10000 + 0.5) / 10000 end
local CENTER = Vector2.new(0.5, 0.5)

-- Figma px -> Scale relative to the parent. Anchor is the center unless a
-- non-center anchor is passed together with the reason for it (section 4).
local function place(obj, x, y, w, h, pw, ph, anchor, reason)
	anchor = anchor or CENTER
	if anchor ~= CENTER then
		assert(reason, obj.Name .. ": non-center AnchorPoint needs a reason")
		obj:SetAttribute("AnchorReason", reason)
	end
	obj.AnchorPoint = anchor
	obj.Size = S(r4(w / pw), r4(h / ph))
	obj.Position = S(r4((x + w * anchor.X) / pw), r4((y + h * anchor.Y) / ph))
end

local function corner(obj, radiusPx, w, h)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(math.min(0.5, r4(radiusPx / math.min(w, h))), 0)
	c.Parent = obj
	return c
end

local POS = { INSIDE = Enum.BorderStrokePosition.Inner, CENTER = Enum.BorderStrokePosition.Center, OUTSIDE = Enum.BorderStrokePosition.Outer }
local function stroke(obj, weightPx, w, h, color, align, contextual)
	local s = Instance.new("UIStroke")
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = r4(weightPx / math.min(w, h))
	s.Color = color
	s.ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	if not contextual then s.BorderStrokePosition = POS[align or "INSIDE"] end
	s.Parent = obj
	return s
end

local function aspect(obj, w, h, axis)
	local a = Instance.new("UIAspectRatioConstraint")
	a.AspectRatio = w / h
	a.DominantAxis = axis or Enum.DominantAxis.Width
	a.Parent = obj
end

local function text(obj, figmaSize)
	obj.TextScaled = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = math.floor(figmaSize * 1.5)
	c.MinTextSize = 8
	c.Parent = obj
end

-- exported artwork (non-standard shape / detailed element)
local function image(parent, name, assetId, x, y, w, h, pw, ph, slice, anchor, anchorReason)
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = assetId
	place(i, x, y, w, h, pw, ph, anchor, anchorReason)
	if slice then
		i.ScaleType = Enum.ScaleType.Slice
		i.SliceCenter = slice.center
		i.SliceScale = slice.scale or 1
	else
		i.ScaleType = Enum.ScaleType.Fit
		aspect(i, w, h)
	end
	i.Parent = parent
	return i
end
```

For text outlines (Contextual), `min(w,h)` is the TextLabel's own size; tune against the screenshot, usually 0.04–0.08.

## 9. Visual check

1. Studio screenshot (`screen_capture`) vs Figma `get_screenshot`: spacing, stroke thickness, radii, colors, fonts, image sharpness.
2. Device Emulator: 1920×1080, 1366×768, phone (844×390 landscape), tablet (1024×768). Nothing may go off-screen or overlap; strokes must not become hairline or chunky.
3. Blurry images: if an ImageLabel is shown larger than its source, re-export bigger (≤ 1024) or switch to 9-slice.

## Exportar con transparencia exacta (lección de Protect the Pyramid)
- `download_assets` mete fondo gris. Mejor: copiar los frames del gráfico a una hoja temporal, exportarla a
  escala 4 con fondo negro y otra vez con fondo blanco, y sacar el alfa con numpy
  (alfa = 1 − (blanco − negro)/255; color = negro/alfa). Así salen bien los brillos semitransparentes.
- Si se acaba el tope del MCP de Figma: dibujar en SVG (como `kit/ui-generar.luau`) y que Asphalt lo pase a PNG.
