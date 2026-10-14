--!strict
-- Sistema del HUD: registra la pantalla, pide monedas por la red y la repinta con cada respuesta.
-- La UI nunca decide: el botón pide, el servidor comprueba y contesta (Net.coinsChanged).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net.Client)
local Screens = require(ReplicatedStorage.Shared.Kit.Screens)
local HudScreen = require(script.Parent.Parent.UI.Hud)

local Hud = {}

local state: HudScreen.State = { coins = 0, waiting = false }

function Hud.init()
	HudScreen.actions.collect = function()
		if state.waiting then
			return
		end
		state.waiting = true
		Screens.render("Hud", state)
		Net.collectCoins.fire()
		-- Si el servidor no da monedas (espera entre pedidos), el botón vuelve a responder solo.
		task.delay(1, function()
			state.waiting = false
			Screens.render("Hud", state)
		end)
	end
	Net.coinsChanged.setCallback(function(balance: number)
		state.coins = balance
		state.waiting = false
		Screens.render("Hud", state)
	end)
end

function Hud.start()
	Screens.register("Hud", HudScreen)
	Screens.render("Hud", state)
end

return Hud
