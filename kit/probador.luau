--!strict
-- Probador de roblox-kit. Luau puro, sin require ni APIs de Lune ni de Roblox: el mismo archivo corre en Lune
-- (kit/probar.luau) y dentro de un servidor de Roblox (kit/probar-nube.luau).
--
-- Una prueba es un archivo que devuelve una tabla de pruebas con nombre. Cada prueba recibe `expect`:
--   return {
--       ["more speed, less time"] = function(expect)
--           expect(Economy.stealTime(300, 1e6, 4)).toBeLessThan(Economy.stealTime(300, 0, 4))
--       end,
--   }
-- Una tabla dentro de otra es un grupo: su nombre se antepone ("grupo > prueba").

local Probador = {}

export type Spec = { nombre: string, modulo: any, error: string? }
export type Fallo = { archivo: string, prueba: string, error: string }
export type Resultado = { total: number, bien: number, fallos: { Fallo } }

-- Texto corto de un valor para los mensajes de fallo.
local function describir(valor: any, profundidad: number?): string
	local p = profundidad or 0
	local tipo = typeof(valor)
	if tipo == "string" then
		return string.format("%q", valor)
	elseif tipo == "table" then
		if p >= 2 then
			return "{...}"
		end
		local partes = {}
		local n = 0
		for clave, v in valor do
			n += 1
			if n > 8 then
				table.insert(partes, "...")
				break
			end
			local textoClave = if typeof(clave) == "string" then clave else "[" .. describir(clave, p + 1) .. "]"
			table.insert(partes, textoClave .. " = " .. describir(v, p + 1))
		end
		return "{" .. table.concat(partes, ", ") .. "}"
	end
	return tostring(valor)
end

local function igualProfundo(a: any, b: any, vistos: { [any]: any }?): boolean
	if a == b then
		return true
	end
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return false
	end
	local v = vistos or {}
	if v[a] == b then
		return true
	end
	v[a] = b
	for clave, valor in a do
		if not igualProfundo(valor, b[clave], v) then
			return false
		end
	end
	for clave in b do
		if a[clave] == nil then
			return false
		end
	end
	return true
end

-- Cada comprobación devuelve si se cumple y el mensaje para cuando no se cumple (o para cuando sí, con `never`).
type Comprobacion = (actual: any, ...any) -> (boolean, string)
local comprobaciones: { [string]: Comprobacion } = {
	toBe = function(actual, esperado)
		return rawequal(actual, esperado), `esperaba {describir(esperado)}, llegó {describir(actual)}`
	end,
	toEqual = function(actual, esperado)
		return igualProfundo(actual, esperado), `esperaba igual a {describir(esperado)}, llegó {describir(actual)}`
	end,
	toBeNil = function(actual)
		return actual == nil, `esperaba nil, llegó {describir(actual)}`
	end,
	toBeTruthy = function(actual)
		return not not actual, `esperaba un valor verdadero, llegó {describir(actual)}`
	end,
	toBeFalsy = function(actual)
		return not actual, `esperaba false o nil, llegó {describir(actual)}`
	end,
	toBeGreaterThan = function(actual, n)
		return actual > n, `esperaba más que {describir(n)}, llegó {describir(actual)}`
	end,
	toBeGreaterThanOrEqual = function(actual, n)
		return actual >= n, `esperaba {describir(n)} o más, llegó {describir(actual)}`
	end,
	toBeLessThan = function(actual, n)
		return actual < n, `esperaba menos que {describir(n)}, llegó {describir(actual)}`
	end,
	toBeLessThanOrEqual = function(actual, n)
		return actual <= n, `esperaba {describir(n)} o menos, llegó {describir(actual)}`
	end,
	toBeCloseTo = function(actual, n, decimales)
		local margen = 10 ^ -(decimales or 2) / 2
		return math.abs(actual - n) < margen, `esperaba cerca de {describir(n)}, llegó {describir(actual)}`
	end,
	toContain = function(actual, elemento)
		if typeof(actual) == "string" then
			return string.find(actual, elemento, 1, true) ~= nil,
				`esperaba que {describir(actual)} contuviera {describir(elemento)}`
		end
		for _, v in actual do
			if v == elemento then
				return true, `esperaba que no contuviera {describir(elemento)}`
			end
		end
		return false, `esperaba que {describir(actual)} contuviera {describir(elemento)}`
	end,
	toHaveLength = function(actual, n)
		return #actual == n, `esperaba longitud {n}, llegó {#actual}`
	end,
	toThrow = function(actual, fragmento)
		local ok, err = pcall(actual)
		if ok then
			return false, "esperaba un error y no lo hubo"
		end
		if fragmento ~= nil and not string.find(tostring(err), fragmento, 1, true) then
			return false, `esperaba un error con {describir(fragmento)}, llegó {describir(tostring(err))}`
		end
		return true, `no esperaba error, llegó {describir(tostring(err))}`
	end,
}

local function crearExpect(actual: any, negar: boolean): any
	return setmetatable({}, {
		__index = function(_, nombre: string)
			if nombre == "never" then
				return crearExpect(actual, not negar)
			end
			local comprobar = comprobaciones[nombre]
			if not comprobar then
				error(`expect: no existe .{nombre}()`, 2)
			end
			return function(...)
				local cumple, mensaje = comprobar(actual, ...)
				if cumple == negar then
					-- Nivel 2: el error señala la línea de la prueba, no esta.
					error((if negar then "(never) " else "") .. mensaje, 2)
				end
			end
		end,
	})
end

function Probador.expect(actual: any): any
	return crearExpect(actual, false)
end

-- Carga un archivo de pruebas sin romper el resto si falla al cargar.
function Probador.cargar(nombre: string, cargador: () -> any): Spec
	local ok, resultado = pcall(cargador)
	if not ok then
		-- Sin la pila: con la primera línea basta y gasta menos.
		local mensaje = tostring(resultado)
		mensaje = string.match(mensaje, "^(.-)\n%s*stack traceback") or mensaje
		return { nombre = nombre, modulo = nil, error = mensaje }
	end
	return { nombre = nombre, modulo = resultado }
end

local function nombresOrdenados(t: { [any]: any }): { string }
	local nombres = {}
	for clave in t do
		table.insert(nombres, tostring(clave))
	end
	table.sort(nombres)
	return nombres
end

-- Corre todas las pruebas. `filtro` (opcional) deja solo las que contienen ese texto en su nombre o archivo.
function Probador.correr(specs: { Spec }, filtro: string?): Resultado
	local resultado: Resultado = { total = 0, bien = 0, fallos = {} }

	local function correrTabla(archivo: string, tabla: { [any]: any }, prefijo: string)
		for _, nombre in nombresOrdenados(tabla) do
			local valor = tabla[nombre]
			local completo = prefijo .. nombre
			if typeof(valor) == "table" then
				correrTabla(archivo, valor, completo .. " > ")
			elseif typeof(valor) == "function" then
				if filtro == nil or string.find(completo, filtro, 1, true) or string.find(archivo, filtro, 1, true) then
					resultado.total += 1
					local ok, err = pcall(valor, Probador.expect)
					if ok then
						resultado.bien += 1
					else
						table.insert(resultado.fallos, { archivo = archivo, prueba = completo, error = tostring(err) })
					end
				end
			end
		end
	end

	for _, spec in specs do
		if spec.error then
			resultado.total += 1
			table.insert(resultado.fallos, { archivo = spec.nombre, prueba = "(cargar)", error = spec.error })
		elseif typeof(spec.modulo) ~= "table" then
			resultado.total += 1
			table.insert(
				resultado.fallos,
				{ archivo = spec.nombre, prueba = "(cargar)", error = "no devuelve una tabla de pruebas" }
			)
		else
			correrTabla(spec.nombre, spec.modulo, "")
		end
	end
	return resultado
end

-- Una línea si todo va bien; si no, una línea por fallo.
function Probador.resumen(r: Resultado): string
	if #r.fallos == 0 then
		return `pruebas: {r.bien} bien`
	end
	local lineas = { `pruebas: {#r.fallos} fallan de {r.total}` }
	for _, f in r.fallos do
		table.insert(lineas, `  {f.archivo} > {f.prueba}: {f.error}`)
	end
	return table.concat(lineas, "\n")
end

return Probador
