// guardar-mapa: copia los trozos del mapa de Studio al repo, sin pasar por el chat ni gastar tokens.
//   node <plugin>/kit/guardar-mapa.js [Trozo ...]      desde la carpeta del juego, con su copia abierta en Studio
// - Workspace.Map.<Trozo>            -> map/fixed/<Trozo>.rbxm
// - ServerStorage.MapPieces.<Trozo>  -> map/pieces/<Trozo>.rbxm
// - ServerStorage.Prefabs.<Trozo>    -> map/prefabs/<Trozo>.rbxm
// - ReplicatedStorage.Models.<Nombre> -> models/<Nombre>.rbxm (modelos 3D ya montados: skill modelos-3d)
// - La luz y el ambiente (Lighting y sus efectos) -> map/Ambience.project.json, solo lo que cambia respecto a
//   lo de Roblox (legible en git; build.project.json lo aplica).
// Sin nombres, guarda todos. Cada trozo sale con SerializationService en Studio (modo edición), viaja en base64
// en trozos y se comprueba con una suma de control en los dos lados. HttpEnabled no hace falta.
// Después: comprobar (mitad sin Studio del mapa) y commit diciendo qué cambió.
const fs = require("fs");
const path = require("path");
const { abrir } = require("../scripts/studio/cliente");

const CARPETAS = [
  { studio: "workspace:FindFirstChild('Map')", repo: "map/fixed" },
  { studio: "game:GetService('ServerStorage'):FindFirstChild('MapPieces')", repo: "map/pieces" },
  { studio: "game:GetService('ServerStorage'):FindFirstChild('Prefabs')", repo: "map/prefabs" },
  { studio: "game:GetService('ReplicatedStorage'):FindFirstChild('Models')", repo: "models" },
];
const TROZO = 180000; // caracteres de base64 por llamada

// FNV-1a de 32 bits: la misma cuenta en Luau (abajo) y aquí.
function suma(bytes) {
  let h = 0x811c9dc5;
  for (const b of bytes) {
    h ^= b;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

// Luau común: serializa un trozo, lo pasa a base64 y calcula su suma.
const LUAU_BASE = `
local HttpService = game:GetService("HttpService")
local function carpeta(i)
	local lista = { ${CARPETAS.map((c) => c.studio).join(", ")} }
	return lista[i]
end
local function serializar(i, nombre)
	local c = carpeta(i)
	local hijo = c and c:FindFirstChild(nombre)
	if not hijo then return nil end
	return game:GetService("SerializationService"):SerializeInstancesAsync({ hijo })
end
local function suma(b)
	-- h * 16777619 (= 2^24 + 403) módulo 2^32, sin pasarse de la precisión de los números de Luau.
	local h = 0x811c9dc5
	for i = 0, buffer.len(b) - 1 do
		h = bit32.bxor(h, buffer.readu8(b, i))
		h = (h * 403 + bit32.lshift(h, 24)) % 4294967296
	end
	return h
end
local ALFABETO = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(b)
	local ok, texto = pcall(function()
		return buffer.tostring(game:GetService("EncodingService"):Base64Encode(b))
	end)
	if ok then return texto end
	local partes, n = {}, buffer.len(b)
	for i = 0, n - 1, 3 do
		local a, c, d = buffer.readu8(b, i), if i + 1 < n then buffer.readu8(b, i + 1) else 0, if i + 2 < n then buffer.readu8(b, i + 2) else 0
		local v = a * 65536 + c * 256 + d
		local s = ""
		for k = 3, 0, -1 do
			local idx = bit32.band(bit32.rshift(v, k * 6), 63) + 1
			s ..= string.sub(ALFABETO, idx, idx)
		end
		if i + 1 >= n then s = string.sub(s, 1, 2) .. "==" elseif i + 2 >= n then s = string.sub(s, 1, 3) .. "=" end
		table.insert(partes, s)
	end
	return table.concat(partes)
end
`;

function luauLista() {
  return `${LUAU_BASE}
local salida = {}
for i = 1, ${CARPETAS.length} do
	local c = carpeta(i)
	if c then
		for _, hijo in c:GetChildren() do
			if hijo.Name ~= "KitMapCheck" then
				local b = serializar(i, hijo.Name)
				local texto = base64(b)
				table.insert(salida, { carpeta = i, nombre = hijo.Name, bytes = buffer.len(b), largo = #texto, suma = suma(b) })
			end
		end
	end
end
return HttpService:JSONEncode(salida)`;
}

function luauTrozo(i, nombre, desde, hasta) {
  return `${LUAU_BASE}
local b = serializar(${i}, ${JSON.stringify(nombre)})
return string.sub(base64(b), ${desde}, ${hasta})`;
}

// Lighting y sus efectos: solo lo que no es lo de por defecto, en formato de proyecto de Rojo.
const LUAU_AMBIENTE = `
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local PROPS = {
	Lighting = { "Ambient", "Brightness", "ClockTime", "ColorShift_Bottom", "ColorShift_Top", "EnvironmentDiffuseScale",
		"EnvironmentSpecularScale", "ExposureCompensation", "FogColor", "FogEnd", "FogStart", "GeographicLatitude",
		"GlobalShadows", "OutdoorAmbient", "ShadowSoftness" },
	Atmosphere = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" },
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId",
		"SunAngularSize", "MoonAngularSize", "StarCount", "CelestialBodiesShown" },
	BloomEffect = { "Enabled", "Intensity", "Size", "Threshold" },
	ColorCorrectionEffect = { "Enabled", "Brightness", "Contrast", "Saturation", "TintColor" },
	SunRaysEffect = { "Enabled", "Intensity", "Spread" },
	DepthOfFieldEffect = { "Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity" },
	BlurEffect = { "Enabled", "Size" },
	ColorGradingEffect = { "Enabled", "TonemapperPreset" },
}
local function valor(v)
	local t = typeof(v)
	if t == "Color3" then return { math.floor(v.R * 1000 + 0.5) / 1000, math.floor(v.G * 1000 + 0.5) / 1000, math.floor(v.B * 1000 + 0.5) / 1000 } end
	if t == "number" then return math.floor(v * 10000 + 0.5) / 10000 end
	if t == "boolean" or t == "string" then return v end
	if t == "Content" then return v.Uri or "" end
	if t == "EnumItem" then return v.Name end
	return nil
end
local function cambios(objeto, base)
	local props = {}
	for _, p in PROPS[objeto.ClassName] or {} do
		local ok, v = pcall(function() return objeto[p] end)
		local okBase, b = pcall(function() return base[p] end)
		if ok and okBase and v ~= b then
			local x = valor(v)
			if x ~= nil then props[p] = x end
		end
	end
	return props
end
local base = Instance.new("Folder")
local nodo = { ["$className"] = "Lighting", ["$ignoreUnknownInstances"] = true }
local referencia = {
	Lighting = { Ambient = Color3.fromRGB(70, 70, 70), Brightness = 2, ClockTime = 14, ColorShift_Bottom = Color3.new(), ColorShift_Top = Color3.new(),
		EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0, ExposureCompensation = 0, FogColor = Color3.fromRGB(192, 192, 192),
		FogEnd = 100000, FogStart = 0, GeographicLatitude = 0, GlobalShadows = true, OutdoorAmbient = Color3.fromRGB(128, 128, 128), ShadowSoftness = 0.2 },
}
local props = cambios(Lighting, referencia.Lighting)
if next(props) then nodo["$properties"] = props end
-- Todos los hijos (menos scripts): los que no están en PROPS se guardan igual, con sus valores de Roblox, para
-- que no desaparezcan sin avisar.
for _, hijo in Lighting:GetChildren() do
	if not hijo:IsA("LuaSourceContainer") then
		local entrada = { ["$className"] = hijo.ClassName }
		local ok, nuevo = pcall(Instance.new, hijo.ClassName)
		if ok then
			local p = cambios(hijo, nuevo)
			nuevo:Destroy()
			if next(p) then entrada["$properties"] = p end
		end
		nodo[hijo.Name] = entrada
	end
end
base:Destroy()
return HttpService:JSONEncode({ name = "Ambience", tree = nodo })`;

(async () => {
  const raiz = process.cwd();
  const proyecto = ["build.project.json", "default.project.json"].map((p) => path.join(raiz, p)).find((p) => fs.existsSync(p));
  if (!proyecto || !fs.existsSync(path.join(raiz, "map"))) {
    console.log("guardar-mapa: lánzalo desde la carpeta del juego (con build.project.json y map/).");
    process.exit(1);
  }
  const nombreJuego = JSON.parse(fs.readFileSync(proyecto, "utf8")).name;
  const pedidos = process.argv.slice(2);
  const s = await abrir(nombreJuego).catch(() => abrir());
  try {
    console.log(`guardar-mapa: Studio «${s.studio.name}»`);
    const lista = JSON.parse(await s.luau(luauLista(), "Edit", 300));
    const elegidos = pedidos.length ? lista.filter((t) => pedidos.includes(t.nombre)) : lista;
    for (const p of pedidos) if (!lista.some((t) => t.nombre === p)) console.log(`  ojo: no hay trozo «${p}» en Studio`);
    const guardados = new Set();
    for (const t of elegidos) {
      let texto = "";
      for (let desde = 1; desde <= t.largo; desde += TROZO) {
        texto += (await s.luau(luauTrozo(t.carpeta, t.nombre, desde, Math.min(desde + TROZO - 1, t.largo)), "Edit", 300)).trim();
      }
      const bytes = Buffer.from(texto, "base64");
      if (bytes.length !== t.bytes || suma(bytes) !== t.suma) {
        throw new Error(`«${t.nombre}» llegó roto (${bytes.length}/${t.bytes} bytes, suma ${suma(bytes)}/${t.suma}). No se ha escrito; repite.`);
      }
      const destino = path.join(raiz, CARPETAS[t.carpeta - 1].repo, `${t.nombre}.rbxm`);
      fs.mkdirSync(path.dirname(destino), { recursive: true });
      fs.writeFileSync(destino, bytes);
      guardados.add(destino);
      console.log(`  ${path.relative(raiz, destino).replace(/\\/g, "/")} (${Math.round(t.bytes / 1024)} KB)`);
    }
    if (!pedidos.length) {
      const ambiente = JSON.parse(await s.luau(LUAU_AMBIENTE, "Edit", 60));
      fs.writeFileSync(path.join(raiz, "map", "Ambience.project.json"), JSON.stringify(ambiente, null, 2) + "\n");
      console.log("  map/Ambience.project.json");
      // Archivos de trozos que ya no están en Studio: no se borran solos, se avisa.
      for (const c of CARPETAS) {
        const dir = path.join(raiz, c.repo);
        if (!fs.existsSync(dir)) continue;
        for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".rbxm"))) {
          if (!guardados.has(path.join(dir, f))) console.log(`  ojo: ${c.repo}/${f} ya no está en Studio (bórralo a mano si sobra)`);
        }
      }
    }
    console.log(`guardar-mapa: bien (${elegidos.length} trozo(s)). Ahora comprobar y commit diciendo qué cambió.`);
  } finally {
    s.cerrar();
  }
})().catch((e) => {
  console.log("guardar-mapa: " + e.message);
  process.exit(1);
});
