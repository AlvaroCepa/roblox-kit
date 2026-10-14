--!strict
-- Pantalla de ejemplo: contador de monedas y botón de pedir, pegados al borde izquierdo.
-- Forma de toda pantalla: create(parent) la monta una vez; render(state) pone todos sus valores.
-- La pantalla no decide ni llama a la red: el sistema que la usa (Systems/Hud) le pasa `actions`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Rules.Format)
local Texts = require(ReplicatedStorage.Shared.Data.Texts)
local UI = require(ReplicatedStorage.Shared.Kit.UI)
local Style = require(script.Parent.Style)

export type State = { coins: number, waiting: boolean }

local Hud = {}

Hud.hud = true
-- Peor caso para el comprobador de UI: el número más largo y el botón esperando.
Hud.sample = { coins = 1.2e12, waiting = true } :: State
-- Lo pone el sistema que usa la pantalla.
Hud.actions = {
	collect = function() end,
}

local coinsLabel: TextLabel? = nil
local collectButton: ImageButton? = nil

function Hud.create(parent: Instance): GuiObject
	local root = UI.new("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		AnchorReason = "pinned to the left edge",
		Position = UDim2.fromScale(0.02, 0.5),
		Size = UDim2.fromScale(0.16, 0.3),
	}, {
		UI.aspect(0.75, Enum.DominantAxis.Height),
		UI.row(0.06, true),
	})
	local coins = Style.label({ Name = "Coins", Text = "0", Size = UDim2.fromScale(1, 0.3) })
	coins.LayoutOrder = 1
	coins.Parent = root
	local button = Style.depthButton({
		Name = "Collect",
		Text = Texts.collect,
		Color = "green",
		Size = UDim2.fromScale(1, 0.4),
		LayoutOrder = 2,
		Activated = function()
			Hud.actions.collect()
		end,
	})
	button.Parent = root
	coinsLabel, collectButton = coins, button
	root.Parent = parent
	return root
end

function Hud.render(state: State)
	if coinsLabel then
		coinsLabel.Text = Format.short(state.coins)
	end
	if collectButton then
		-- Mientras espera la respuesta del servidor, el botón no responde (sin pedidos dobles).
		collectButton.Active = not state.waiting
		collectButton.ImageTransparency = if state.waiting then 0.35 else 0
	end
end

return Hud
