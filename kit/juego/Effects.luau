--!strict
-- roblox-kit Effects v2
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Efectos visuales con UNA línea, siempre en el cliente (el servidor solo avisa por Zap):
--   Effects.play("Purchase", part)                   en una parte, un Attachment, un Vector3 o un CFrame
--   Effects.play("LegendaryHatch", position, "epic")  con nivel de fuerza (small, normal, epic)
-- Cada efecto es una entrada de src/shared/Data/Effects.luau hecha de piezas (chispas, humo, destellos...)
-- que salen de la biblioteca de VFX del plugin. Nada vive escondido en Studio.
-- En móvil se emiten menos partículas (Style.vfx.mobileFactor). Las texturas van por nombre (Assets).

local UserInputService = game:GetService("UserInputService")

local Asset = require("./Asset")
local Effects_ = require("../Data/Effects")
local Theme = require("./Theme")

local Effects = {}

-- Una pieza: propiedades de un ParticleEmitter más cuántas emite y su textura por nombre.
export type Piece = {
	texture: string, -- nombre en Assets, p. ej. "vfx/sparkle"
	count: number, -- partículas que emite de golpe (en nivel normal)
	color: string?, -- de la paleta
	properties: { [string]: any }?, -- el resto (Lifetime, Speed, Size, SpreadAngle...) tal cual
}
export type Effect = { pieces: { Piece }, duration: number? }

local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local definitions: { [string]: Effect } = Effects_ :: any

local function attachmentAt(target: any): (Attachment, boolean)
	if typeof(target) == "Instance" then
		if target:IsA("Attachment") then
			return target, false
		end
		local a = Instance.new("Attachment")
		a.Parent = target
		return a, true
	end
	local a = Instance.new("Attachment")
	a.WorldCFrame = if typeof(target) == "CFrame" then target else CFrame.new(target :: Vector3)
	a.Parent = workspace.Terrain
	return a, true
end

-- Número de partículas de una pieza para este nivel y este dispositivo.
function Effects.count(piece: Piece, tier: Theme.Tier?): number
	local n = piece.count * Theme.tier("vfx", tier)
	if mobile then
		n *= Theme.style.vfx.mobileFactor
	end
	return math.max(1, math.round(n))
end

-- Devuelve los emisores (sirve para congelarlos con TimeScale = 0 y hacer las capturas de revisión).
function Effects.play(name: string, target: any, tier: Theme.Tier?): { ParticleEmitter }
	local effect = definitions[name]
	if not effect then
		warn(`Effects: "{name}" is not in Data/Effects`)
		return {}
	end
	local attachment, temporary = attachmentAt(target)
	local longest = 0
	local emitters: { ParticleEmitter } = {}
	for _, piece in effect.pieces do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.Rate = 0
		-- Sin subir todavía: se queda la chispa de Roblox, para que el efecto se vea mientras tanto.
		local texture = Asset.get(piece.texture)
		if texture then
			emitter.Texture = texture
		end
		if piece.color then
			emitter.Color = ColorSequence.new(Theme.color(piece.color))
		end
		local writable: any = emitter
		for key, value in (piece.properties or {}) :: { [string]: any } do
			writable[key] = value
		end
		emitter.Parent = attachment
		longest = math.max(longest, emitter.Lifetime.Max)
		table.insert(emitters, emitter)
		emitter:Emit(Effects.count(piece, tier))
	end
	task.delay(math.max(longest, effect.duration or 0) + 0.1, function()
		if temporary then
			attachment:Destroy()
		else
			for _, e in emitters do
				e:Destroy()
			end
		end
	end)
	return emitters
end

return Effects
