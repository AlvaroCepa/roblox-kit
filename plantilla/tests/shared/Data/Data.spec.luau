-- Comprobación de los datos (Lune): números con sentido y textos visibles que no están vacíos.
local CoinsData = require("@src/shared/Data/Coins")
local Texts = require("@src/shared/Data/Texts")

return {
	["coin numbers make sense"] = function(expect)
		expect(CoinsData.reward).toBeGreaterThan(0)
		expect(CoinsData.cooldown).toBeGreaterThanOrEqual(0)
		expect(CoinsData.maxBalance).toBeGreaterThan(CoinsData.reward)
	end,
	["no visible text is empty"] = function(expect)
		for key, text in Texts do
			-- La clave sale en el mensaje si su texto está vacío.
			expect({ [key] = string.match(text, "%S") ~= nil }).toEqual({ [key] = true })
		end
	end,
}
