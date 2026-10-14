--!strict
-- roblox-kit Sounds v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Sonidos con UNA línea, en el cliente (el servidor solo avisa por Zap):
--   Sounds.play("Click")                      sin posición (UI, música de un momento)
--   Sounds.play("Coin", part, "epic")          en una parte o posición, con nivel de fuerza
--   Sounds.music("Lobby")                      pista de una zona, con fundido; nunca corta de golpe
--   Sounds.setMusicMuted(true)                 el botón de silenciar la música
-- Cada sonido es una entrada de src/shared/Data/Sounds.luau: asset por nombre (Assets o la biblioteca de
-- Roblox), volumen, tono, variación y canal. Tres canales con su volumen en Style.sound.volumes.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Asset = require("./Asset")
local Sounds_ = require("../Data/Sounds")
local Theme = require("./Theme")

local Sounds = {}

export type Channel = "music" | "sfx" | "ui"
export type Sound = {
	asset: string, -- nombre en Assets ("sounds/coin"); o "library:<id>" para la biblioteca de audio de Roblox
	channel: Channel?, -- por defecto sfx
	volume: number?, -- 0..1 (antes del canal)
	pitch: number?,
	variation: number?, -- ± tono al azar (0.05 = ±5 %)
	looped: boolean?,
}

local definitions: { [string]: Sound } = Sounds_ :: any
local style = Theme.style.sound
local groups: { [string]: SoundGroup } = {}
local playing: { [string]: number } = {}
local currentMusic: { name: string, sound: Sound? }? = nil
local musicSound: Instance? = nil
local musicMuted = false

local function group(channel: Channel): SoundGroup
	local found = groups[channel]
	if found then
		return found
	end
	local g = Instance.new("SoundGroup")
	g.Name = "Kit_" .. channel
	g.Volume = (style.volumes :: { [string]: number })[channel] or 1
	g.Parent = SoundService
	groups[channel] = g
	return g
end

local function soundId(asset: string): string
	local library = string.match(asset, "^library:(%d+)$")
	if library then
		return "rbxassetid://" .. library
	end
	return Asset.id(asset)
end

local function make(name: string, tier: Theme.Tier?): Sound?
	local definition = definitions[name]
	if not definition then
		warn(`Sounds: "{name}" is not in Data/Sounds`)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId(definition.asset)
	sound.Volume = (definition.volume or 0.5) * Theme.tier("sound", tier)
	local variation = definition.variation or 0
	sound.PlaybackSpeed = (definition.pitch or 1) * (1 + (math.random() * 2 - 1) * variation)
	sound.Looped = definition.looped == true
	sound.SoundGroup = group(definition.channel or "sfx")
	return sound :: any
end

function Sounds.play(name: string, at: any?, tier: Theme.Tier?)
	-- Tope de copias del mismo sonido a la vez: las que pasan no suenan.
	if (playing[name] or 0) >= style.maxSame then
		return
	end
	local sound = make(name, tier) :: any
	if not sound then
		return
	end
	local holder: Instance = SoundService
	local temporary: Instance? = nil
	if typeof(at) == "Instance" then
		holder = at
	elseif typeof(at) == "Vector3" or typeof(at) == "CFrame" then
		local a = Instance.new("Attachment")
		a.WorldPosition = if typeof(at) == "CFrame" then at.Position else at
		a.Parent = workspace.Terrain
		holder, temporary = a, a
	end
	sound.Parent = holder
	playing[name] = (playing[name] or 0) + 1
	sound.Ended:Once(function()
		playing[name] -= 1
		sound:Destroy()
		if temporary then
			temporary:Destroy()
		end
	end)
	sound:Play()
end

local function fade(sound: Instance, volume: number, done: (() -> ())?)
	local t = TweenService:Create(sound, TweenInfo.new(style.musicFade), { Volume = volume })
	if done then
		t.Completed:Once(done)
	end
	t:Play()
end

-- Cambia la música con fundido. nil = silencio.
function Sounds.music(name: string?)
	if currentMusic and currentMusic.name == name then
		return
	end
	local old = musicSound
	if old then
		fade(old, 0, function()
			old:Destroy()
		end)
	end
	musicSound = nil
	currentMusic = nil
	if not name then
		return
	end
	local sound = make(name) :: any
	if not sound then
		return
	end
	local target = sound.Volume
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	musicSound = sound
	currentMusic = { name = name }
	fade(sound, if musicMuted then 0 else target)
	sound:SetAttribute("TargetVolume", target)
end

function Sounds.setMusicMuted(muted: boolean)
	musicMuted = muted
	local sound = musicSound
	if sound then
		fade(sound, if muted then 0 else (sound:GetAttribute("TargetVolume") :: number?) or 0.5)
	end
end

function Sounds.isMusicMuted(): boolean
	return musicMuted
end

return Sounds
