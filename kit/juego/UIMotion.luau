--!strict
-- roblox-kit UIMotion v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Animaciones estándar de la UI, con los tiempos de la hoja de estilo (Style.motion). Todas animan Size
-- (en Scale): con AnchorPoint centrado, crecen y encogen desde el centro. Nada de UIScale (rompe los
-- UIStroke en ScaledSize) ni CanvasGroup para desvanecer (emborrona).

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require("./Theme")

local UIMotion = {}

local motion = Theme.style.motion

local function scaled(size: UDim2, factor: number): UDim2
	return UDim2.fromScale(size.X.Scale * factor, size.Y.Scale * factor)
end

local function tween(object: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t =
		TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Tamaño "de reposo" de un elemento: el que tenía la primera vez que se animó.
local function restSize(object: GuiObject): UDim2
	local saved = object:GetAttribute("RestSize")
	if typeof(saved) == "UDim2" then
		return saved
	end
	object:SetAttribute("RestSize", object.Size)
	return object.Size
end

-- Aparece con un pequeño rebote.
function UIMotion.popIn(object: GuiObject)
	local rest = restSize(object)
	object.Size = scaled(rest, 0.6)
	object.Visible = true
	tween(object, motion.popIn, { Size = rest }, Enum.EasingStyle.Back)
end

-- Se encoge y se esconde. `done` se llama al terminar.
function UIMotion.popOut(object: GuiObject, done: (() -> ())?)
	local rest = restSize(object)
	local t = tween(object, motion.popOut, { Size = scaled(rest, 0.6) })
	t.Completed:Once(function()
		object.Visible = false
		object.Size = rest
		if done then
			done()
		end
	end)
end

-- Encoge al pulsar y, en PC, crece un poco al pasar el ratón. Devuelve una función que lo desconecta.
function UIMotion.button(button: GuiButton): () -> ()
	local rest = restSize(button)
	local hovering = false
	local connections = {
		button.MouseButton1Down:Connect(function()
			tween(button, motion.press, { Size = scaled(rest, motion.pressScale) })
		end),
		button.MouseButton1Up:Connect(function()
			tween(button, motion.press, { Size = if hovering then scaled(rest, motion.hoverScale) else rest })
		end),
	}
	if UserInputService.MouseEnabled then
		table.insert(
			connections,
			button.MouseEnter:Connect(function()
				hovering = true
				tween(button, motion.press, { Size = scaled(rest, motion.hoverScale) })
			end)
		)
		table.insert(
			connections,
			button.MouseLeave:Connect(function()
				hovering = false
				tween(button, motion.press, { Size = rest })
			end)
		)
	end
	return function()
		for _, c in connections do
			c:Disconnect()
		end
	end
end

-- Un número que sube contando hasta `to`. `format` lo convierte en texto (los formatos van en shared/Rules).
function UIMotion.countUp(label: TextLabel, from: number, to: number, format: (number) -> string)
	local value = Instance.new("NumberValue")
	value.Value = from
	local connection = value.Changed:Connect(function(n: number)
		label.Text = format(n)
	end)
	local t = tween(value, motion.countUp, { Value = to })
	t.Completed:Once(function()
		connection:Disconnect()
		label.Text = format(to)
		value:Destroy()
	end)
end

-- Enseña un aviso un rato y lo esconde (el aviso ya existe y está escondido).
function UIMotion.toast(object: GuiObject)
	UIMotion.popIn(object)
	task.delay(motion.toast, function()
		if object.Visible then
			UIMotion.popOut(object)
		end
	end)
end

return UIMotion
