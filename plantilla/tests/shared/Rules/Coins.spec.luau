-- Pruebas de las reglas de las monedas (Lune). Cada prueba recibe `expect`.
local Coins = require("@src/shared/Rules/Coins")
local CoinsData = require("@src/shared/Data/Coins")

return {
	["the first collect is always allowed"] = function(expect)
		expect(Coins.canCollect(nil, 0)).toBe(true)
	end,
	["collecting again too soon is not allowed"] = function(expect)
		expect(Coins.canCollect(10, 10 + CoinsData.cooldown / 2)).toBe(false)
		expect(Coins.canCollect(10, 10 + CoinsData.cooldown)).toBe(true)
	end,
	["the balance never goes over the cap"] = function(expect)
		expect(Coins.collect(CoinsData.maxBalance)).toBe(CoinsData.maxBalance)
		expect(Coins.collect(0)).toBe(CoinsData.reward)
	end,
}
