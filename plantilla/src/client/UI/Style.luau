--!strict
-- Funciones de estilo del juego: todos los botones y paneles salen de aquí, así todos quedan iguales.
-- Los cuerpos son imágenes blancas en 9-slice (assets/ui/kit/*.svg, generadas desde Data/Style con
-- kit/ui-generar.luau) teñidas con ImageColor3. Lo nativo solo coloca y pone el texto.
-- Este archivo es del juego: se puede cambiar, pero los valores salen siempre de Data/Style.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Asset = require(ReplicatedStorage.Shared.Kit.Asset)
local Theme = require(ReplicatedStorage.Shared.Kit.Theme)
local UI = require(ReplicatedStorage.Shared.Kit.UI)
local UIMotion = require(ReplicatedStorage.Shared.Kit.UIMotion)

local Style = {}

local body = Theme.style.ui.body
local CORNER_PX = body.corner + body.stroke
-- Zona fija del 9-slice: las esquinas (y abajo, también el labio y la sombra) no se estiran.
local SLICE = Rect.new(CORNER_PX, CORNER_PX, body.size - CORNER_PX, body.size - CORNER_PX - body.shadowOffset)

-- El 9-slice va en píxeles: se reajusta con el tamaño del elemento para que las esquinas escalen con la pantalla.
local function keepSliceScale(image: any)
	local function update()
		local short = math.min(image.AbsoluteSize.X, image.AbsoluteSize.Y)
		image.SliceScale = math.max(0.01, short * Theme.style.ui.bodyCorner / CORNER_PX)
	end
	image:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
end

local function bodyImage(className: string, kind: string, color: string, props: UI.Props): any
	local image = Asset.get(`ui/kit/{kind}`)
	local base = {
		BackgroundTransparency = 1,
		Image = image or "",
		ImageColor3 = Theme.color(color),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = SLICE,
	}
	for key, value in props do
		base[key] = value
	end
	local object = UI.new(className, base)
	if image then
		keepSliceScale(object)
	else
		-- Sin la imagen subida: versión nativa provisional (se ve plana, pero funciona).
		object.BackgroundTransparency = 0
		object.BackgroundColor3 = Theme.color(color)
		UI.corner().Parent = object
		UI.stroke().Parent = object
	end
	return object
end

-- Botón con profundidad: cuerpo de imagen teñido y texto con contorno encima de la cara (no del labio).
function Style.depthButton(props: {
	Name: string,
	Text: string,
	Color: string?,
	Size: UDim2,
	Position: UDim2?,
	LayoutOrder: number?,
	Activated: (() -> ())?,
}): ImageButton
	local button = bodyImage("ImageButton", "button", props.Color or "green", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		LayoutOrder = props.LayoutOrder or 0,
	})
	UI.new("TextLabel", {
		Name = "Label",
		Text = props.Text,
		Size = UDim2.fromScale(0.86, 0.62),
		Position = UDim2.fromScale(0.5, 0.44),
	}, { UI.stroke(nil, true) }).Parent =
		button
	if props.Activated then
		button.Activated:Connect(props.Activated)
	end
	UIMotion.button(button)
	return button
end

-- Panel de fondo (ventanas, tarjetas).
function Style.panel(props: { Name: string, Size: UDim2, Position: UDim2?, Color: string? }): ImageLabel
	return bodyImage("ImageLabel", "panel", props.Color or "panel", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
	})
end

-- Texto normal con el contorno del juego.
function Style.label(props: { Name: string, Text: string, Size: UDim2, Position: UDim2?, Color: string? }): TextLabel
	return UI.new("TextLabel", {
		Name = props.Name,
		Text = props.Text,
		Size = props.Size,
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		TextColor3 = Theme.color(props.Color or "light"),
	}, { UI.stroke(nil, true) })
end

return Style
