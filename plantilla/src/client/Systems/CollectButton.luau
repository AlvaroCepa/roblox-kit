--!strict
-- Botón de pedir monedas: tecla E en PC y botón táctil en móvil. Solo pide; el servidor decide.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net.Client)
local Texts = require(ReplicatedStorage.Shared.Data.Texts)

local CollectButton = {}

local ACTION = "CollectCoins"

function CollectButton.start()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			Net.collectCoins.fire()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.E)
	ContextActionService:SetTitle(ACTION, Texts.collect)

	Net.coinsChanged.setCallback(function(_balance: number)
		-- Aquí iría la animación o el sonido de ganar monedas (partes de UI, VFX y sonido).
	end)
end

return CollectButton
