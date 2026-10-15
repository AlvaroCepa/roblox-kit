--!strict
-- roblox-kit UICheck v2
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Mitad «en Studio» del comprobador de UI. Se lanza en modo EDICIÓN (sin Play) con execute_luau:
--   return require(game.ReplicatedStorage.Shared.Kit.UICheck).run()
-- Monta cada pantalla de StarterPlayerScripts.Client.UI (módulos con create) en marcos de 4 tamaños, con sus
-- datos del peor caso (`sample`), y comprueba lo de la skill de UI. Una línea si todo va bien.
--   .show("Hud", "phone")  deja montada una pantalla en un tamaño para hacer la captura; .clear() la quita.
--   Dice qué parte de la vista ocupa el marco (crop=ancho,alto en fracciones, desde arriba a la izquierda) para
--   que captura.js recorte solo el marco.
-- Si todo va bien, la línea empieza por "roblox-kit comprobar-ui: bien": el hook del plugin lo ve y apunta la
-- pasada buena (así el hook de Stop no vuelve a pedirla hasta que cambie la UI).

local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local UICheck = {}

export type Device = { name: string, size: Vector2, mobile: boolean }

UICheck.devices = {
	{ name = "pc", size = Vector2.new(1920, 1080), mobile = false },
	{ name = "tablet", size = Vector2.new(1024, 768), mobile = true },
	{ name = "phone", size = Vector2.new(844, 390), mobile = true },
	{ name = "small", size = Vector2.new(667, 375), mobile = true },
} :: { Device }

local TOPBAR = 58 -- alto de la barra de arriba de Roblox
local MIN_TOUCH = 44
local MIN_TEXT = 12
local CENTER = Vector2.new(0.5, 0.5)
local FOLDER = "KitUICheck"

local function screenModules(): { ModuleScript }
	local client = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	client = client and client:FindFirstChild("Client")
	local ui = client and client:FindFirstChild("UI")
	local list = {}
	if ui then
		for _, m in ui:GetChildren() do
			if m:IsA("ModuleScript") then
				table.insert(list, m)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function holder(): ScreenGui
	local old = StarterGui:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = FOLDER
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = StarterGui
	return gui
end

-- Monta una pantalla en un marco del tamaño del dispositivo (debajo de la barra, como en el juego).
-- `fit` lo encoge (con su proporción) para que quepa en la vista de Studio y salga entero en la captura.
local function mount(gui: ScreenGui, module: ModuleScript, device: Device, fit: boolean?): (GuiObject?, string?)
	local frame = Instance.new("Frame")
	frame.Name = `{module.Name}_{device.name}`
	frame.AnchorPoint = Vector2.zero
	frame.Position = UDim2.fromOffset(0, 0)
	local scale = 1
	if fit then
		local view = workspace.CurrentCamera.ViewportSize
		scale = math.min(1, view.X / device.size.X, view.Y / device.size.Y)
	end
	frame.Size = UDim2.fromOffset(device.size.X * scale, device.size.Y * scale)
	frame.BackgroundColor3 = Color3.fromRGB(70, 90, 70)
	frame.Parent = gui
	local safe = Instance.new("Frame")
	safe.Name = "Safe"
	safe.BackgroundTransparency = 1
	safe.Position = UDim2.fromOffset(0, TOPBAR * scale)
	safe.Size = UDim2.new(1, 0, 1, -TOPBAR * scale)
	safe.Parent = frame
	local ok, screen = pcall(require, module)
	if not ok then
		return nil, `require failed: {screen}`
	end
	local s = screen :: any
	if typeof(s) ~= "table" or typeof(s.create) ~= "function" then
		return nil, nil
	end
	local created, root = pcall(s.create, safe)
	if not created then
		return nil, `create failed: {root}`
	end
	local r = root :: GuiObject
	r.Visible = true
	if typeof(s.render) == "function" and s.sample ~= nil then
		local rendered, err = pcall(s.render, s.sample)
		if not rendered then
			return nil, `render(sample) failed: {err}`
		end
	end
	return frame, nil
end

type Rect = { min: Vector2, max: Vector2 }

local function rect(o: GuiObject): Rect
	return { min = o.AbsolutePosition, max = o.AbsolutePosition + o.AbsoluteSize }
end

local function overlap(a: Rect, b: Rect): number
	local w = math.min(a.max.X, b.max.X) - math.max(a.min.X, b.min.X)
	local h = math.min(a.max.Y, b.max.Y) - math.max(a.min.Y, b.min.Y)
	return if w > 1 and h > 1 then w * h else 0
end

local function offsetIn(value: any): boolean
	if typeof(value) == "UDim2" then
		return value.X.Offset ~= 0 or value.Y.Offset ~= 0
	end
	return typeof(value) == "UDim" and value.Offset ~= 0
end

local function visible(o: GuiObject, stop: Instance): boolean
	local node: Instance? = o
	while node and node ~= stop do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

-- Comprueba todo lo montado en `frame` para un dispositivo. Añade los problemas a `out`.
local function inspect(frame: GuiObject, device: Device, label: string, out: { string })
	local safe = frame:FindFirstChild("Safe") :: GuiObject
	local screen = rect(frame)
	local function bad(o: Instance, problem: string)
		local path = string.gsub(o:GetFullName(), "^.-Safe%.", "")
		table.insert(out, `{label} [{device.name}] {path}: {problem}`)
	end
	-- Zonas de los controles de móvil (joystick abajo a la izquierda, saltar abajo a la derecha).
	local joystick = {
		min = screen.min + Vector2.new(0, device.size.Y * 0.55),
		max = screen.min + Vector2.new(device.size.X * 0.3, device.size.Y),
	}
	local jump = {
		min = screen.min + Vector2.new(device.size.X * 0.78, device.size.Y * 0.6),
		max = screen.max,
	}

	for _, d in safe:GetDescendants() do
		-- Reglas de propiedades (como el validador de figma-to-roblox-ui).
		if d:IsA("UIStroke") then
			if d.StrokeSizingMode ~= Enum.StrokeSizingMode.ScaledSize then
				bad(d, "UIStroke not in ScaledSize")
			end
		elseif d:IsA("UICorner") then
			if offsetIn(d.CornerRadius) then
				bad(d, "UICorner uses Offset")
			end
		elseif d:IsA("UIListLayout") then
			if offsetIn(d.Padding) then
				bad(d, "UIListLayout.Padding uses Offset")
			end
		elseif d:IsA("UIGridLayout") then
			if offsetIn(d.CellSize) or offsetIn(d.CellPadding) then
				bad(d, "UIGridLayout uses Offset")
			end
		elseif d:IsA("UIPadding") then
			if
				offsetIn(d.PaddingLeft)
				or offsetIn(d.PaddingRight)
				or offsetIn(d.PaddingTop)
				or offsetIn(d.PaddingBottom)
			then
				bad(d, "UIPadding uses Offset")
			end
		end
		if not d:IsA("GuiObject") or not visible(d, safe) then
			continue
		end
		local o = d :: GuiObject
		if offsetIn(o.Size) or offsetIn(o.Position) then
			bad(o, "Size/Position uses Offset (Scale only)")
		end
		if o.AnchorPoint ~= CENTER and not o:GetAttribute("AnchorReason") then
			bad(o, "AnchorPoint not centered and no AnchorReason")
		end
		local r = rect(o)
		if o.AbsoluteSize.X < 1 or o.AbsoluteSize.Y < 1 then
			continue
		end
		-- Fuera de la pantalla o bajo la barra de arriba.
		if
			r.min.X < screen.min.X - 1
			or r.min.Y < screen.min.Y - 1
			or r.max.X > screen.max.X + 1
			or r.max.Y > screen.max.Y + 1
		then
			bad(o, "goes off screen")
		elseif r.min.Y < screen.min.Y + TOPBAR - 1 and not o:GetAttribute("UnderTopbar") then
			bad(o, "covers Roblox's top bar")
		end
		if o:IsA("GuiButton") and o.Active then
			if device.mobile and (o.AbsoluteSize.X < MIN_TOUCH or o.AbsoluteSize.Y < MIN_TOUCH) then
				bad(
					o,
					`button is {math.floor(o.AbsoluteSize.X)}x{math.floor(o.AbsoluteSize.Y)} px, under {MIN_TOUCH} px on mobile`
				)
			end
			if
				device.mobile
				and (overlap(r, joystick) > 0 or overlap(r, jump) > 0)
				and not o:GetAttribute("AllowOverlap")
			then
				bad(o, "button over the mobile joystick or jump button")
			end
		end
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			local t = o :: any
			if t.Text ~= "" then
				if not t.TextFits then
					bad(o, "text does not fit")
				end
				local lines = math.max(1, #string.split(t.Text, "\n"))
				local size = t.TextBounds.Y / lines
				if device.mobile and size > 0 and size < MIN_TEXT then
					bad(o, `text is {math.floor(size)} px, under {MIN_TEXT} px on mobile`)
				end
			end
		end
		-- Centrado: si su Position.X es 0.5 con ancla centrada, su centro va con el del padre (±1.5 px).
		local parent = o.Parent
		if
			parent
			and parent:IsA("GuiObject")
			and o.AnchorPoint.X == 0.5
			and o.Position.X.Scale == 0.5
			and not parent:FindFirstChildWhichIsA("UIPadding")
			and not parent:FindFirstChildWhichIsA("UIGridStyleLayout")
		then
			local mine = o.AbsolutePosition.X + o.AbsoluteSize.X / 2
			local theirs = parent.AbsolutePosition.X + parent.AbsoluteSize.X / 2
			if math.abs(mine - theirs) > 1.5 then
				bad(o, `meant to be centered but is {math.floor(math.abs(mine - theirs))} px off`)
			end
		end
		-- Marcos sobrantes: transparentes, sin nada propio y con un solo hijo que los llena.
		if o.ClassName == "Frame" and o.BackgroundTransparency >= 1 then
			local children = o:GetChildren()
			if #children == 1 and children[1]:IsA("GuiObject") then
				local child = children[1] :: GuiObject
				if child.Size == UDim2.fromScale(1, 1) then
					bad(o, "useless wrapper frame (only wraps one child that fills it)")
				end
			end
		end
		-- Solapes entre hermanos (los de un layout ya los coloca el layout).
		if parent and not parent:FindFirstChildWhichIsA("UIGridStyleLayout") and not o:GetAttribute("AllowOverlap") then
			for _, sibling in parent:GetChildren() do
				if
					sibling ~= o
					and sibling:IsA("GuiObject")
					and sibling.Visible
					and not sibling:GetAttribute("AllowOverlap")
					and sibling.Name > o.Name
					and overlap(r, rect(sibling)) > 0
				then
					bad(o, `overlaps {sibling.Name} (set AllowOverlap if on purpose)`)
				end
			end
		end
	end
end

-- Pasa el comprobador a todas las pantallas. Devuelve el texto del resultado.
function UICheck.run(): string
	local modules = screenModules()
	if #modules == 0 then
		return "roblox-kit comprobar-ui: bien (no hay pantallas en StarterPlayerScripts.Client.UI)"
	end
	local gui = holder()
	local problems: { string } = {}
	local screens = 0
	for _, module in modules do
		local counted = false
		for _, device in UICheck.devices do
			local frame, err = mount(gui, module, device)
			if err then
				table.insert(problems, `{module.Name}: {err}`)
				break
			end
			if frame then
				counted = true
				task.wait() -- deja que Roblox calcule tamaños y textos
				inspect(frame, device, module.Name, problems)
				frame:Destroy()
			end
		end
		if counted then
			screens += 1
		end
	end
	gui:Destroy()
	if #problems == 0 then
		return `roblox-kit comprobar-ui: bien ({screens} pantalla(s) x {#UICheck.devices} tamaños)`
	end
	local shown = {}
	for i = 1, math.min(25, #problems) do
		table.insert(shown, problems[i])
	end
	if #problems > 25 then
		table.insert(shown, `... y {#problems - 25} más`)
	end
	return `roblox-kit comprobar-ui: falla ({#problems} problema(s))\n` .. table.concat(shown, "\n")
end

-- Deja montada una pantalla en un tamaño, para la captura (encogida para caber en la vista). Devuelve lo que pasó.
function UICheck.show(screen: string, deviceName: string?): string
	local gui = holder()
	for _, module in screenModules() do
		if module.Name == screen then
			for _, device in UICheck.devices do
				if device.name == (deviceName or "pc") then
					local _, err = mount(gui, module, device, true)
					local view = workspace.CurrentCamera.ViewportSize
					local scale = math.min(1, view.X / device.size.X, view.Y / device.size.Y)
					local cropX = device.size.X * scale / view.X
					local cropY = device.size.Y * scale / view.Y
					return err
						or string.format(
							"mounted %s at %s (%dx%d) in StarterGui.%s crop=%.4f,%.4f",
							screen,
							device.name,
							device.size.X,
							device.size.Y,
							FOLDER,
							cropX,
							cropY
						)
				end
			end
		end
	end
	gui:Destroy()
	return `no screen "{screen}" or device "{deviceName}"`
end

function UICheck.clear()
	local old = StarterGui:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
end

return UICheck
