--!strict
-- roblox-kit Screens v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Un solo gestor de pantallas en el cliente. Cada pantalla es un módulo de src/client/UI con:
--   create(parent): GuiObject   la monta UNA vez dentro de `parent` y devuelve su raíz.
--   render(state)               pone TODOS sus valores a partir de los datos; se puede llamar siempre.
--   sample: any                 (opcional) datos del peor caso, para el comprobador de UI.
--   hud: true                   (opcional) siempre visible (contador de monedas, botones del borde).
-- Screens.open("Shop") abre una pantalla y cierra la que hubiera, con la misma animación en todas.

local Players = game:GetService("Players")

local UIMotion = require("./UIMotion")

export type Screen = {
	create: (parent: Instance) -> GuiObject,
	render: ((state: any) -> ())?,
	sample: any?,
	hud: boolean?,
}

local Screens = {}

local screens: { [string]: Screen } = {}
local roots: { [string]: GuiObject } = {}
local current: string? = nil
local gui: ScreenGui? = nil

local function container(): ScreenGui
	if gui then
		return gui
	end
	local g = Instance.new("ScreenGui")
	g.Name = "Screens"
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	g.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	gui = g
	return g
end

local function root(name: string): GuiObject
	local found = roots[name]
	if found then
		return found
	end
	local screen = screens[name]
	if not screen then
		error(`Screens: "{name}" is not registered`, 3)
	end
	local r = screen.create(container())
	r.Name = name
	r.Visible = screen.hud == true
	roots[name] = r
	return r
end

-- Registra una pantalla. Las de tipo hud se montan y se ven ya.
function Screens.register(name: string, screen: Screen)
	screens[name] = screen
	if screen.hud then
		root(name)
	end
end

-- Abre una pantalla (y cierra la anterior). `state` se pasa a su render.
function Screens.open(name: string, state: any?)
	if current == name then
		return
	end
	Screens.close()
	local r = root(name)
	local screen = screens[name]
	if screen.render and state ~= nil then
		screen.render(state)
	end
	current = name
	UIMotion.popIn(r)
end

-- Cierra la pantalla abierta, si hay.
function Screens.close()
	local name = current
	if not name then
		return
	end
	current = nil
	UIMotion.popOut(roots[name])
end

function Screens.toggle(name: string, state: any?)
	if current == name then
		Screens.close()
	else
		Screens.open(name, state)
	end
end

-- Vuelve a pintar una pantalla con datos nuevos (aunque esté cerrada: así al abrirla ya está al día).
function Screens.render(name: string, state: any)
	local screen = screens[name]
	if screen and screen.render then
		root(name)
		screen.render(state)
	end
end

function Screens.current(): string?
	return current
end

return Screens
