--!strict
-- Reglas de las monedas. Lógica pura: sin game ni servicios de Roblox, para probarla con Lune en un segundo.
local CoinsData = require("../Data/Coins")

local Coins = {}

-- ¿Puede pedir monedas ya? `lastTime` es la hora del último pedido (nil si nunca pidió).
function Coins.canCollect(lastTime: number?, now: number): boolean
	return lastTime == nil or now - lastTime >= CoinsData.cooldown
end

-- Saldo después de un pedido, sin pasar del tope.
function Coins.collect(balance: number): number
	return math.min(balance + CoinsData.reward, CoinsData.maxBalance)
end

return Coins
