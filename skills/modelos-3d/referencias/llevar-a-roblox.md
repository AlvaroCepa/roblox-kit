# Del modelo aprobado al juego

1. Copia a `assets/models/<modelo>/` el `<modelo>.glb` y sus texturas (la base y una por mutación) de
   `.kit/3d/<modelo>/`. Sube con `kit/subir-assets.ps1` (pregunta antes; avisa de la moderación). Los ids quedan en
   `src/shared/Assets/models.luau` (`models.<modelo>.<archivo>`).
2. En Studio (modo Edit), monta el modelo en `ReplicatedStorage.Models` con execute_luau (cambia los nombres):
```lua
local InsertService = game:GetService("InsertService")
local models = require(game.ReplicatedStorage.Shared.Assets.models)
local datos = models.perro
local function id(texto) return tonumber(string.match(texto, "%d+")) end
local cargado = InsertService:LoadAsset(id(datos.perro))
local malla = cargado:FindFirstChildWhichIsA("MeshPart", true)
local destino = game.ReplicatedStorage:FindFirstChild("Models") or Instance.new("Folder")
destino.Name = "Models"
destino.Parent = game.ReplicatedStorage
malla.Name = "Perro"
malla.Anchored = false
malla.CanCollide = false -- mascotas y decoración no chocan
malla.CanTouch = false
malla.CanQuery = false
malla.CollisionFidelity = Enum.CollisionFidelity.Box
malla.RenderFidelity = Enum.RenderFidelity.Automatic
for nombre, textura in datos do
	if nombre ~= "perro" then -- una SurfaceAppearance por textura: la base y cada mutación
		local sa = Instance.new("SurfaceAppearance")
		sa.Name = nombre
		sa.ColorMap = textura
		sa.Parent = malla
	end
end
malla.Parent = destino
cargado:Destroy()
return malla:GetFullName()
```
   - Si una textura sale en blanco, su id puede ser el «decal» y no la imagen:
     `game:GetObjects("rbxassetid://<id>")[1].Texture` da el de la imagen. Y lo recién subido tarda unos minutos.
   - Solo una `SurfaceAppearance` puede estar puesta: deja la base y guarda las de mutación aparte (por ejemplo en
     una carpeta `Mutations` dentro del modelo); el juego clona la que toque al crear la mascota.
3. Guárdalo en el repo: `node <kit>/kit/guardar-mapa.js` también guarda cada hijo de `ReplicatedStorage.Models` en
   `models/<Nombre>.rbxm` (Rojo lo lleva a Studio y al build).
4. El código lo pide por nombre (`ReplicatedStorage.Models.Perro`), nunca por id.
