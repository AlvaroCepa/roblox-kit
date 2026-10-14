--!strict
-- roblox-kit Asset v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Ids de imágenes, sonidos, animaciones y modelos POR NOMBRE, nunca un número suelto en el código.
-- Los genera Asphalt en src/shared/Assets/<entrada>.luau al subir assets/<entrada>/ (asphalt.toml).
--   Asset.get("ui/body")            -> "rbxassetid://..." o nil si aún no está subido
--   Asset.get("sounds/ui/click")    -> ruta dentro de la entrada, sin extensión
-- Si falta, avisa una vez por nombre (y se ve en la consola y en probar-nube).

local Asset = {}

local warned: { [string]: boolean } = {}

local function folder(): Instance?
	return script.Parent and script.Parent.Parent and script.Parent.Parent:FindFirstChild("Assets")
end

function Asset.get(path: string): string?
	local parts = string.split(path, "/")
	local assets = folder()
	local module = assets and assets:FindFirstChild(parts[1])
	local node: any = nil
	if module and module:IsA("ModuleScript") then
		node = require(module) :: any
		for i = 2, #parts do
			node = if typeof(node) == "table" then node[parts[i]] else nil
		end
	end
	if typeof(node) == "string" and node ~= "" then
		return node
	end
	if not warned[path] then
		warned[path] = true
		warn(`Asset: "{path}" is not uploaded yet (assets/{path}.* -> kit/subir-assets.ps1)`)
	end
	return nil
end

-- Como get, pero sin id da un texto vacío (sirve para propiedades que no aceptan nil, como Image).
function Asset.id(path: string): string
	return Asset.get(path) or ""
end

return Asset
