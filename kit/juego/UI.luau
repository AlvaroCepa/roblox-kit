--!strict
-- roblox-kit UI v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Constructor pequeño de UI en código. Aplica solo las reglas de la skill de UI, así no se pueden romper:
-- - Todo en Scale: un Offset distinto de 0 en Size, Position o cualquier UDim es un error.
-- - AnchorPoint centrado por defecto. Otro solo con el motivo en `AnchorReason`.
-- - UIStroke en ScaledSize. Texto escalado con UITextSizeConstraint y la fuente del juego.
-- - Sin borde nativo (BorderSizePixel = 0).
--
--   UI.new("Frame", { Name = "Shop", Size = UDim2.fromScale(0.5, 0.6), BackgroundTransparency = 1 }, {
--       Title = UI.new("TextLabel", { Text = Texts.shop, Size = UDim2.fromScale(1, 0.15) }),
--       UI.corner(),
--   })
-- Un valor función conecta el evento del mismo nombre: { Activated = function() ... end }.

local Theme = require("./Theme")

local UI = {}

export type Props = { [string]: any }

local CENTER = Vector2.new(0.5, 0.5)
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }
local OWN_KEYS = { AnchorReason = true, MaxTextSize = true, MinTextSize = true }

local function checkScale(instance: Instance, key: string, value: any)
	if typeof(value) == "UDim2" then
		if value.X.Offset ~= 0 or value.Y.Offset ~= 0 then
			error(`UI: {instance.Name}.{key} uses Offset; use Scale only (UDim2.fromScale)`, 4)
		end
	elseif typeof(value) == "UDim" and value.Offset ~= 0 then
		error(`UI: {instance.Name}.{key} uses Offset; use Scale only (UDim.new(scale, 0))`, 4)
	end
end

-- Crea una instancia con sus propiedades y sus hijos (en lista o con nombre: { Title = ... }).
function UI.new(className: string, props: Props?, children: { [any]: any }?): any
	local instance = Instance.new(className :: any)
	local p: Props = props or {}

	if instance:IsA("GuiObject") then
		instance.AnchorPoint = CENTER
		instance.BorderSizePixel = 0
		local anchor = p.AnchorPoint
		if anchor and anchor ~= CENTER and not p.AnchorReason then
			error(`UI: {p.Name or className} has a non-centered AnchorPoint; say why in AnchorReason`, 2)
		end
		if p.AnchorReason then
			instance:SetAttribute("AnchorReason", p.AnchorReason)
		end
	end
	if instance:IsA("UIStroke") then
		instance.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		instance.Color = Theme.color(Theme.style.ui.strokeColor)
		instance.Thickness = Theme.style.ui.stroke
	end
	if TEXT_CLASSES[className] then
		local text = instance :: any
		text.TextScaled = true
		text.FontFace = Theme.font()
		text.TextColor3 = Theme.color("light")
		text.BackgroundTransparency = 1
		local size = Instance.new("UITextSizeConstraint")
		size.MaxTextSize = p.MaxTextSize or Theme.style.ui.maxTextSize
		size.MinTextSize = p.MinTextSize or Theme.style.ui.minTextSize
		size.Parent = instance
	end
	if instance:IsA("GuiButton") then
		local button: any = instance
		button.AutoButtonColor = false
	end

	for key, value in p do
		if OWN_KEYS[key] then
			continue
		end
		if typeof(value) == "function" then
			local signal: RBXScriptSignal = (instance :: any)[key]
			signal:Connect(value)
		else
			checkScale(instance, key, value)
			local target: any = instance
			target[key] = value
		end
	end

	if children then
		for name, child in children do
			if typeof(name) == "string" then
				child.Name = name
			end
			child.Parent = instance
		end
	end
	return instance
end

-- Esquinas en Scale (fracción del lado corto; 0.5 = píldora). Por defecto, las de la hoja de estilo.
function UI.corner(radius: number?): any
	return UI.new("UICorner", { CornerRadius = UDim.new(radius or Theme.style.ui.corner, 0) })
end

-- El contorno del juego (un único grosor). `contextual` para el contorno de un texto.
function UI.stroke(color: string?, contextual: boolean?): any
	local stroke = UI.new("UIStroke", {
		Color = Theme.color(color or Theme.style.ui.strokeColor),
		ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
	})
	if contextual then
		stroke.Thickness = Theme.style.ui.textStroke
	end
	return stroke
end

-- Mantiene la proporción ancho/alto en cualquier pantalla.
function UI.aspect(ratio: number, axis: Enum.DominantAxis?): any
	return UI.new("UIAspectRatioConstraint", { AspectRatio = ratio, DominantAxis = axis or Enum.DominantAxis.Width })
end

-- Márgenes interiores en Scale.
function UI.padding(x: number, y: number?): any
	return UI.new("UIPadding", {
		PaddingLeft = UDim.new(x, 0),
		PaddingRight = UDim.new(x, 0),
		PaddingTop = UDim.new(y or x, 0),
		PaddingBottom = UDim.new(y or x, 0),
	})
end

-- Fila o columna con separación en Scale, ordenada por LayoutOrder.
function UI.row(gap: number, vertical: boolean?): any
	return UI.new("UIListLayout", {
		FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		Padding = UDim.new(gap, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
end

return UI
