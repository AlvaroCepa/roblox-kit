--!strict
-- roblox-kit Motion v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Movimiento hecho con código, sin archivos de animación ni subidas, en el cliente:
--   local stop = Motion.bob(pet)            flota arriba y abajo
--   Motion.spin(coin)                       gira sobre sí
--   Motion.shake(egg, 0.6, "epic")          tiembla un rato y para solo
--   Motion.pop(model)                       crece con rebote al aparecer
-- Todo lo que se mueve va en UN solo bucle (RenderStepped), nunca uno por objeto. Mueve el modelo entero
-- (PivotTo) desde su posición de partida; los números salen de Style.animation y sus niveles.

local RunService = game:GetService("RunService")

local Theme = require("./Theme")

local Motion = {}

type Target = Model | BasePart
type Job = {
	target: Target,
	base: CFrame,
	started: number,
	duration: number?, -- nil = hasta que se pare
	step: (t: number) -> CFrame, -- desplazamiento respecto a base en el instante t
}

local jobs: { [Target]: Job } = {}
local connection: RBXScriptConnection? = nil
local style = Theme.style.animation

local function loop()
	local now = os.clock()
	for target, job in jobs do
		if not target.Parent then
			jobs[target] = nil
			continue
		end
		local t = (now - job.started) * style.speed
		if job.duration and t >= job.duration then
			target:PivotTo(job.base)
			jobs[target] = nil
		else
			target:PivotTo(job.base * job.step(t))
		end
	end
	if next(jobs) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function run(target: Target, duration: number?, step: (t: number) -> CFrame): () -> ()
	local old = jobs[target]
	local base = if old then old.base else target:GetPivot()
	jobs[target] = { target = target, base = base, started = os.clock(), duration = duration, step = step }
	if not connection then
		connection = RunService.RenderStepped:Connect(loop)
	end
	return function()
		if jobs[target] then
			target:PivotTo(jobs[target].base)
			jobs[target] = nil
		end
	end
end

function Motion.bob(target: Target, tier: Theme.Tier?): () -> ()
	local height = 0.5 * Theme.tier("animation", tier)
	return run(target, nil, function(t)
		return CFrame.new(0, math.sin(t * 2.5) * height, 0)
	end)
end

function Motion.spin(target: Target, tier: Theme.Tier?): () -> ()
	local speed = 2 * Theme.tier("animation", tier)
	return run(target, nil, function(t)
		return CFrame.Angles(0, t * speed, 0)
	end)
end

function Motion.shake(target: Target, duration: number, tier: Theme.Tier?): () -> ()
	local angle = math.rad(6) * Theme.tier("animation", tier)
	return run(target, duration, function(t)
		local fadeOut = 1 - t / duration
		return CFrame.Angles(0, 0, math.sin(t * 40) * angle * fadeOut)
	end)
end

-- Rebote al aparecer: sube un poco y vuelve, con el rebote de la hoja de estilo.
function Motion.pop(target: Target, tier: Theme.Tier?): () -> ()
	local height = 1.2 * Theme.tier("animation", tier)
	local duration = 0.45
	return run(target, duration, function(t)
		local x = t / duration
		local y = math.sin(x * math.pi) * height * (1 + style.bounce) * (1 - x * 0.5)
		return CFrame.new(0, y, 0)
	end)
end

return Motion
