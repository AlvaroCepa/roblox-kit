--!strict
-- roblox-kit Animations v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Animaciones de personaje (archivos subidos al grupo) con UNA línea, en el cliente:
--   Animations.play(humanoid, "Celebrate")
--   Animations.stop(humanoid, "Celebrate")
-- Cada una es una entrada de src/shared/Data/Animations.luau: asset por nombre, prioridad, velocidad,
-- bucle y fundido. Andar, saltar y moverse son las de Roblox: no van aquí.

local Asset = require("./Asset")
local Animations_ = require("../Data/Animations")
local Theme = require("./Theme")

local Animations = {}

export type Animation = {
	asset: string, -- nombre en Assets ("anims/celebrate")
	priority: Enum.AnimationPriority?,
	speed: number?,
	looped: boolean?,
	fade: number?,
}

local definitions: { [string]: Animation } = Animations_ :: any
local tracks: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

local function animatorOf(humanoid: Humanoid | AnimationController): Animator
	local found = humanoid:FindFirstChildOfClass("Animator")
	if found then
		return found
	end
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

local function track(holder: Humanoid | AnimationController, name: string): AnimationTrack?
	local animator = animatorOf(holder)
	local cache = tracks[animator]
	if not cache then
		cache = {}
		tracks[animator] = cache
	end
	local found = cache[name]
	if found then
		return found
	end
	local definition = definitions[name]
	if not definition then
		warn(`Animations: "{name}" is not in Data/Animations`)
		return nil
	end
	local id = Asset.get(definition.asset)
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local t = animator:LoadAnimation(animation)
	t.Priority = definition.priority or Enum.AnimationPriority.Action
	t.Looped = definition.looped == true
	cache[name] = t
	return t
end

function Animations.play(holder: Humanoid | AnimationController, name: string, tier: Theme.Tier?)
	local t = track(holder, name)
	if t then
		local definition = definitions[name]
		local speed = (definition.speed or 1) * Theme.style.animation.speed
		t:Play(definition.fade or 0.15, 1, speed * math.sqrt(Theme.tier("animation", tier)))
	end
end

function Animations.stop(holder: Humanoid | AnimationController, name: string)
	local animator = holder:FindFirstChildOfClass("Animator")
	local cache = animator and tracks[animator :: Animator]
	local t = cache and cache[name]
	if t then
		t:Stop(definitions[name].fade or 0.15)
	end
end

return Animations
