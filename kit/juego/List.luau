--!strict
-- roblox-kit List v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Listas de la UI (tienda, inventario) que reutilizan cada fila por su id: sin duplicados ni tirones.
--   local list = List.new(scrollingFrame, createRow, updateRow)
--   list:set(items)   -- items = { { id = "dog", ... }, ... } en el orden en que se ven
-- createRow(item) crea la fila una vez; updateRow(row, item) pone sus valores cada vez.

export type Item = { id: string, [any]: any }

local List = {}
List.__index = List

export type List = typeof(setmetatable(
	{} :: {
		container: Instance,
		createRow: (item: any) -> GuiObject,
		updateRow: (row: GuiObject, item: any) -> (),
		rows: { [string]: GuiObject },
	},
	List
))

function List.new(
	container: Instance,
	createRow: (item: any) -> GuiObject,
	updateRow: (row: GuiObject, item: any) -> ()
): List
	return setmetatable({ container = container, createRow = createRow, updateRow = updateRow, rows = {} }, List)
end

function List.set(self: List, items: { Item })
	local seen: { [string]: boolean } = {}
	for index, item in items do
		if seen[item.id] then
			warn(`List: id "{item.id}" is repeated; only the first is shown`)
			continue
		end
		seen[item.id] = true
		local row: GuiObject? = self.rows[item.id]
		if not row then
			local created = self.createRow(item)
			created.Name = item.id
			created.Parent = self.container
			self.rows[item.id] = created
			row = created
		end
		local shown = row :: GuiObject
		shown.LayoutOrder = index
		self.updateRow(shown, item)
	end
	for id, row in self.rows do
		if not seen[id] then
			row:Destroy()
			self.rows[id] = nil
		end
	end
end

function List.destroy(self: List)
	for _, row in self.rows do
		row:Destroy()
	end
	table.clear(self.rows)
end

return List
