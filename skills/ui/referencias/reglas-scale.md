# Reglas de Scale, imágenes y propiedades

> Adaptado de la skill `figma-to-roblox-ui` (licencia MIT, © 2026 Xtrair). En los juegos de roblox-kit
> el constructor `Kit/UI` ya aplica las reglas duras (Scale, ancla, ScaledSize, texto escalado) y el
> comprobador `Kit/UICheck` hace lo del validador; esto queda como referencia de cómo y por qué.
> **Ojo:** en nuestros juegos los cuerpos de botones y paneles son SIEMPRE imagen (aunque sean rectángulos):
> así quedan profesionales. Lo nativo (Frame con UICorner y UIGradient) es solo para lo que no se ve como botón.

## 0. Reglas duras

1. **Scale everywhere, Offset = 0.** `Size`, `Position`, `UIListLayout.Padding`, `UIGridLayout.CellSize/CellPadding`, every `UIPadding` side, `UIShadow.Offset/BlurRadius/Spread` — Scale component only. Offset is always `0`.
2. **AnchorPoint = `Vector2.new(0.5, 0.5)` on every GuiObject by default**, so `Position` is the element's center. With a corner anchor like `(0, 0)`, UIAspectRatioConstraint, Size tweens and resolution changes shrink/grow the box toward that corner, so buttons and panels skew and drift away from their Figma spot. Use another anchor only when there is a concrete reason (section 4, "When not to center") and record it in the `AnchorReason` attribute so the validator accepts it.
3. **UIStroke always uses `StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize`.** In this mode `Thickness` is a fraction of the *parent's shortest axis* (0.1 on a 200×300 frame = 20 px). Keep values between 0 and 1. `BorderOffset` is Scale too.
4. **UICorner always uses Scale.** `CornerRadius = UDim.new(radius / min(w, h), 0)`. Scale is measured against the shortest side; `0.5` = full pill/circle. For different corners use `TopLeftRadius / TopRightRadius / BottomLeftRadius / BottomRightRadius` (also Scale). Do not set `CornerRadius` and per-corner radii at the same time.
5. **Detailed art and non-standard shapes are exported from Figma as images and placed as ImageLabel/ImageButton** — never approximated with Frames (see section 2).
6. Text: `TextScaled = true` + `UITextSizeConstraint` (MaxTextSize ≈ Figma size × 1.5, MinTextSize ≈ 8). No fixed `TextSize`.
7. After every build, run the validator (section 8) and compare screenshots at several resolutions (section 9).

## 2. Native vs image — the decision (how pros do it)

Professional Figma → Roblox workflow: **structure, layout and text are native; artwork is images.** Roblox can only draw rectangles and rounded rectangles with a flat fill, linear gradient, border and drop shadow. Everything beyond that is exported from Figma as PNG and dropped into Studio as ImageLabel/ImageButton.

### ALWAYS export as an image

- **Non-standard shapes** — anything that is not a rectangle / rounded rectangle / circle: stars, hexagons, shields, badges, ribbons, banners with cut ends, speech bubbles with tails, arrows, tabs with slanted edges, blobs, torn paper, irregular panels, custom vector paths, boolean-op shapes. UICorner and UIStroke only follow the rectangular box, so they can't reproduce these.
- **Highly detailed elements** — multi-layer buttons (glossy highlight + inner shadow + bevel + outline), panels with bevels, texture, stud/noise patterns, illustrations, character art, item/currency/rarity icons, logos, decorative frames and borders.
- **Effects Roblox can't render** — inner shadow, layer blur, background blur, blend modes, radial/angular/diamond gradients, image fills with masks, multiple stacked strokes, dashed strokes, strokes on custom shapes.
- **Stylized text** that uses a font Roblox doesn't have, or heavy effects (multiple outlines, gradient fill + 3D extrusion) — titles and logo text only; normal UI text stays TextLabel.

### Build natively

- Plain rectangles/rounded rectangles with a flat fill or linear gradient, a single border and a drop shadow → Frame + UICorner + UIGradient + UIStroke + UIShadow. Zero textures, perfectly crisp on any screen.
- All regular text (labels, prices, counters, descriptions) → TextLabel with a Roblox font. Crisp at every resolution, changeable from scripts, localizable.
- Containers, lists, grids, scroll areas → Frame / ScrollingFrame + layouts.

### Hybrid (the typical pro result)

A shop button is usually: `ImageButton` (exported artwork of the button body without text) → `TextLabel` child (price/text, native) → `ImageLabel` child (coin icon). The layout around it is native Frames in Scale.

### How pros export the images

- **Separate the art from the text.** Hide text layers before exporting the body; text is rebuilt as TextLabel.
- **Export each asset as its own layer/frame**, tightly cropped to the visible content, transparent background, PNG. Include the outline and outer glow/shadow *inside* the image if they are part of the art — then size the ImageLabel to the exported bounds, not the Figma shape size.
- **Resolution:** the longest side ≤ 1024 px (Roblox limit — anything bigger is downscaled and blurs). Usually @2x for elements ≤ 512 px in the mockup, exact 1024 for large ones.
- **Stretchable art → 9-slice.** Panels, bars, buttons with a custom shape but uniform edges: export a small version (e.g. 128×128 / 256×256), `ScaleType = Slice`, `SliceCenter = Rect(inset, inset, size−inset, size−inset)`, tune `SliceScale` so corners match the mockup. One texture stretches to any size without blur.
- **Color variants → one white/grey base + `ImageColor3`.** Rarity slots, team colors, button colors: export a neutral light version once and tint in Studio instead of uploading 6 copies.
- **Button states** (normal / hover / pressed / disabled): either separate images swapped from script, or one base image with `ImageColor3`/size tweens. Set `AutoButtonColor = false` when you handle states yourself.
- **Many small icons → spritesheet** 1024×1024, one upload, `ImageRectOffset` / `ImageRectSize` per ImageLabel. Saves memory and upload limits.
- **Artwork larger than 1024** (full-screen illustration) → cut into tiles ≤ 1024 (2×2, 3×2) and assemble with several ImageLabels in a Scale grid inside one Frame with UIAspectRatioConstraint. Tiles butt exactly edge to edge, `ResampleMode = Default`.
- Pixel art → `ResampleMode = Pixelated`.
- Every exported image still gets `UIAspectRatioConstraint` = exported width / height, so it never stretches.

## 4. px → Scale formulas

For an element (x, y, w, h) inside a parent (pw, ph), relative coordinates:

```
Size      = UDim2.fromScale(w / pw, h / ph)
Position  = UDim2.fromScale((x + w*ax) / pw, (y + h*ay) / ph)   -- ax,ay = AnchorPoint (default 0.5, 0.5)
Corner    = UDim.new(radius / min(w, h), 0)                       -- max 0.5
Stroke    = Thickness = strokeWeight / min(w, h)  (ScaledSize)
ListPad   = UDim.new(gap / pw, 0) (horizontal) | UDim.new(gap / ph, 0) (vertical)
UIPadding = Left/Right: p / pw ; Top/Bottom: p / ph
```

- **Default AnchorPoint = (0.5, 0.5)**, so `Position = UDim2.fromScale((x + w/2) / pw, (y + h/2) / ph)`, the center of the Figma box. The `place` helper does this unless you pass another anchor.
- A child's Position is always measured from the parent's top-left corner, whatever the parent's AnchorPoint, so the formulas stay the same at every level.
- If the parent has UIPadding, pw/ph = its *inner* area.
- Round Scale values to 4 decimals.

### When not to center

Change the anchor only when the element must stay glued to a side or grow from one side. Put the anchor on that side and set the `AnchorReason` attribute (the `place` helper does it for you):
- **HUD pinned to a screen edge or corner** (currency top-left, menu buttons on the left edge, hotbar at the bottom): anchor on that edge/corner, e.g. `(0, 0)`, `(0, 0.5)`, `(0.5, 1)`, `(1, 1)`. With a center anchor, UIAspectRatioConstraint pulls it away from the edge on narrow and wide screens.
- **Progress / health / XP bar fill** that grows through `Size.X`: `(0, 0.5)`, so it fills from the left.
- **Dropdowns, tooltips, lists with AutomaticSize** that must expand in one direction: anchor on the side that stays fixed (usually the top, `(0.5, 0)`).

Everything else (panels, buttons, icons, text, images, slots) stays `(0.5, 0.5)`.

### Keeping proportions
Scale on both axes stretches elements on wide/narrow screens, so:
- Every **root panel**, button, icon, avatar, slot and exported image gets `UIAspectRatioConstraint` with `AspectRatio = w/h` from Figma; pick `DominantAxis` by intent (usually Width for horizontal panels, Height for HUD on screen edges).
- Children inside such a panel are already Scale relative to it → proportions stay intact automatically.
- Round elements: AspectRatio = 1 + CornerRadius Scale 0.5.

## 5. Property mapping Figma → Roblox

| Figma | Roblox |
|---|---|
| Layer x/y | `AnchorPoint = (0.5, 0.5)`, `Position` = center of the layer box in Scale (section 4) |
| Rectangle frame with fill | `Frame` (BackgroundColor3, BackgroundTransparency = 1 − opacity) |
| Frame without fill | `Frame`, BackgroundTransparency = 1 |
| Non-standard shape / detailed art | `ImageLabel`/`ImageButton` with exported PNG (section 2), BackgroundTransparency = 1 |
| Raster image | `ImageLabel` (BackgroundTransparency = 1, ScaleType = Fit or Slice) |
| Text | `TextLabel` (TextScaled, UITextSizeConstraint, FontFace, TextXAlignment/TextYAlignment) |
| Button | `ImageButton`/`TextButton` (AutoButtonColor = false if it has its own hover) |
| Clip content | `ClipsDescendants = true` (does not clip to rounded corners — use `CanvasGroup` for that, but it is memory-heavy, use sparingly) |
| Stroke Inside / Center / Outside | `UIStroke.BorderStrokePosition = Inner / Center / Outer` |
| Stroke weight | `Thickness = weight / min(w,h)`, `StrokeSizingMode = ScaledSize` |
| Text outline | `UIStroke` with `ApplyStrokeMode = Contextual` inside the TextLabel, also ScaledSize |
| Corner radius | `UICorner` in Scale; different corners → per-corner *Radius properties |
| Drop shadow | `UIShadow`: Offset = UDim2.fromScale(dx/w, dy/h), BlurRadius/Spread = UDim.new(v/min(w,h), 0), Color, Transparency = 1 − alpha, ZIndex < 0. Compare blur against the screenshot — Figma and Roblox blur are not 1:1 |
| Inner shadow, blur, blend mode | export as image |
| Linear gradient | `UIGradient`: Color = ColorSequence, Transparency = NumberSequence (1 − alpha), Rotation = atan2(dy·h, dx·w) in degrees from gradientHandlePositions. Max 20 keypoints |
| Radial/angular gradient | export as image |
| Auto Layout | `UIListLayout` (FillDirection, Padding in Scale, SortOrder = LayoutOrder, alignment) + `UIPadding` in Scale; LayoutOrder = layer order |
| Grid | `UIGridLayout` (CellSize/CellPadding in Scale) + `UIAspectRatioConstraint` on the cell |
| Scroll | `ScrollingFrame` (CanvasSize = UDim2.fromScale(0,0), AutomaticCanvasSize = Y/X, thin ScrollBarThickness) |
| Group opacity | `CanvasGroup.GroupTransparency` (only when really needed — expensive) |
| Layer order | `ZIndex` by layer order (bottom layer = lowest ZIndex), ScreenGui.ZIndexBehavior = Sibling |

## 6. Uploading and performance

1. **Upload:** via the Roblox Studio MCP (`upload_image`/`store_image` if available), otherwise Asset Manager → Bulk Import, or the Open Cloud Assets API. Keep a table `layer name → rbxassetid://ID` to avoid duplicate uploads. Images go through moderation — until approved they render blank; that is not a layout bug.
2. **Performance:** fewer than 300 visible UIStrokes and fewer than 100 UIShadows at once (Roblox guidance for low-end devices). CanvasGroup only where group alpha or rounded clipping is required. Reuse images (tint with ImageColor3, spritesheets) to save texture memory.

## 10. Common mistakes

- **Buttons skew or drift when resized, on other screens or during hover tweens** → AnchorPoint left at `(0, 0)`. Use `(0.5, 0.5)`; other anchors only for edge-pinned HUD, fill bars and one-way expanding elements (section 4).
- **Elements drift apart on other screens** → missing UIAspectRatioConstraint on root panels, or coordinates computed from the root instead of the direct parent.
- **Custom shape rebuilt from Frames looks cheap/wrong** → it should have been an exported image (section 2).
- **Stroke thickness differs on same-style buttons** → in ScaledSize thickness depends on min(w,h); compute Thickness per size with the formula, don't copy the number.
- **Rounded corners missing on an image** → UICorner must be inside the ImageLabel itself; ClipsDescendants doesn't clip to rounded corners. For non-rectangular art, bake the shape into the PNG.
- **Jagged shadow** → large CornerRadius + UIShadow causes jaggies (known limitation); reduce BlurRadius or bake the shadow into the image.
- **Text size differs between neighboring buttons** → TextScaled fits the box; equalize TextLabel heights and MaxTextSize.
- **Blurry art** → image > 1024 or stretched beyond its source; see section 2.
- **Text baked into images** → blurry, can't be changed from scripts or localized; keep it as TextLabel unless it is a stylized title.
- **Plugins (FigBloxUI, RoImport, Bloxporter, Figma To Roblox)** save time, but ALWAYS run their output through the validator: they can leave Offset, `(0, 0)` anchors, FixedSize strokes and px radii. Figma components/variants don't carry over — they become plain instances.
