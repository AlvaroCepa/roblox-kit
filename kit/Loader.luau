--!strict
-- roblox-kit Loader v1
-- Copia del original del plugin (kit/Loader.luau). No se edita en el juego: se actualiza desde el plugin.
--
-- Arranca los sistemas de una carpeta en dos fases, como Knit y Nevermore:
--   1. init() de todos: se preparan y se conectan. No debe esperar (nada de task.wait ni llamadas que esperen).
--   2. start() de todos: empiezan a funcionar. Cada uno en su propio hilo, así que puede esperar.
-- Cada hijo ModuleScript de la carpeta es un sistema y devuelve una tabla con init y/o start.
-- Cada sistema va protegido: si uno falla, la consola dice cuál y en qué fase, y los demás siguen.
-- En el servidor deja dos atributos en ServerScriptService para probar-nube: KitReady y KitFailed.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

type System = {
	init: ((self: any) -> ())?,
	start: ((self: any) -> ())?,
}

local Loader = {}

-- Llama a fn(system) protegido y devuelve si fue bien y, si no, el error con su pila.
local function protect(fn: (any) -> (), system: any): (boolean, string?)
	local message: string? = nil
	local ok = xpcall(fn, function(err)
		message = debug.traceback(tostring(err), 2)
	end, system)
	return ok, message
end

function Loader.run(folder: Instance)
	local isServer = RunService:IsServer()
	local failed: { string } = {}

	local function fail(name: string, phase: string, message: any)
		table.insert(failed, `{name} ({phase})`)
		if isServer then
			ServerScriptService:SetAttribute("KitFailed", table.concat(failed, ", "))
		end
		-- Como error (en rojo) para que se vea en la consola y lo recoja probar-nube.
		task.spawn(error, `[Loader] {name} failed in {phase}: {message}`, 0)
	end

	local modules = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)

	local systems: { { name: string, system: System } } = {}
	for _, module in modules do
		local ok, result = pcall(require, module)
		if not ok then
			fail(module.Name, "require", result)
		elseif typeof(result) ~= "table" then
			fail(module.Name, "require", "does not return a table")
		else
			table.insert(systems, { name = module.Name, system = result :: System })
		end
	end

	local ready = {}
	for _, entry in systems do
		local init = entry.system.init
		if init then
			local ok, err = protect(init, entry.system)
			if not ok then
				fail(entry.name, "init", err)
				continue
			end
		end
		table.insert(ready, entry)
	end

	for _, entry in ready do
		local start = entry.system.start
		if start then
			task.spawn(function()
				local ok, err = protect(start, entry.system)
				if not ok then
					fail(entry.name, "start", err)
				end
			end)
		end
	end

	if isServer then
		ServerScriptService:SetAttribute("KitReady", true)
	end
end

return Loader
