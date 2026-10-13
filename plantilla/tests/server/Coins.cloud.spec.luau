-- Prueba de nube: solo corre en un servidor de Roblox de verdad (probar-nube, en «Pruebas»), nunca en Lune.
-- Aquí los módulos se cargan como en el juego: por instancia, no por ruta.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

return {
	["the loader started every server system"] = function(expect)
		expect(ServerScriptService:GetAttribute("KitReady")).toBe(true)
		expect(ServerScriptService:GetAttribute("KitFailed")).toBeNil()
	end,
	["the coin rules work on a real server"] = function(expect)
		local Coins = require(ReplicatedStorage.Shared.Rules.Coins)
		expect(Coins.canCollect(nil, os.clock())).toBe(true)
	end,
}
