// captura: saca capturas de Studio (modo edición, sin Play) y las pone al lado de las referencias en UNA imagen,
// para que Álvaro juzgue. No pasa por el chat: deja el PNG en .kit/capturas/ y dice la ruta (Claude la mira con Read).
// Desde la carpeta del juego, con su copia abierta en Studio:
//   node <plugin>/kit/captura.js ui <Pantalla> [pc|tablet|phone|small|todos] [--ref img ...]
//   node <plugin>/kit/captura.js mapa <Trozo> [--ref img ...]       desde su marca CameraPoint (Chunk = Trozo)
//   node <plugin>/kit/captura.js mapa-arriba                         desde arriba (con las marcas rojas de MapCheck)
//   node <plugin>/kit/captura.js vfx <Efecto> [small|normal|epic]    principio, mitad y final, congelados
// Las referencias (capturas de juegos, imágenes de concepto) van a la izquierda; lo de Studio, a la derecha.
// Juntarlas lo hace scripts/lado-a-lado.py (Python con Pillow, lo instala el diagnóstico).
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { abrir } = require("../scripts/studio/cliente");

const KIT = "game:GetService('ReplicatedStorage').Shared.Kit";
const DISPOSITIVOS = ["pc", "tablet", "phone", "small"];

function argumentos() {
  const sueltos = [];
  const refs = [];
  const a = process.argv.slice(2);
  for (let i = 0; i < a.length; i++) {
    if (a[i] === "--ref") {
      while (a[i + 1] && !a[i + 1].startsWith("--")) refs.push(a[++i]);
    } else sueltos.push(a[i]);
  }
  return { sueltos, refs };
}

async function capturar(s, nombre, camara) {
  const args = { capture_id: "ScreenCapture_" + Date.now() };
  if (camara) Object.assign(args, camara);
  const contenido = await s.llamar("screen_capture", args, 60);
  const imagen = contenido.find((c) => c.type === "image");
  if (!imagen) throw new Error("screen_capture no devolvió imagen (¿ventana de Studio minimizada?)");
  const ruta = path.join(os.tmpdir(), `roblox-kit-${nombre}-${Date.now()}.png`);
  fs.writeFileSync(ruta, Buffer.from(imagen.data, "base64"));
  return ruta;
}

function juntar(salida, refs, capturas, titulo) {
  const script = path.join(__dirname, "..", "scripts", "lado-a-lado.py");
  const py = process.platform === "win32" ? "py" : "python3";
  const args = process.platform === "win32" ? ["-3", script] : [script];
  execFileSync(py, [...args, salida, "--titulo", titulo, "--refs", ...refs, "--capturas", ...capturas], { stdio: "inherit" });
}

(async () => {
  const { sueltos, refs } = argumentos();
  const [tipo, nombre, extra] = sueltos;
  if (!["ui", "mapa", "mapa-arriba", "vfx"].includes(tipo) || (tipo !== "mapa-arriba" && !nombre)) {
    console.log("Uso: node captura.js ui <Pantalla> [dispositivo|todos] | mapa <Trozo> | mapa-arriba | vfx <Efecto> [nivel]  [--ref img ...]");
    process.exit(1);
  }
  for (const r of refs) if (!fs.existsSync(r)) throw new Error("no existe la referencia " + r);
  // El Studio con la copia de este juego (el nombre del proyecto de Rojo); si no, el que haya.
  let nombreJuego;
  try {
    nombreJuego = JSON.parse(fs.readFileSync(path.join(process.cwd(), "default.project.json"), "utf8")).name;
  } catch {}
  const s = await abrir(nombreJuego).catch(() => abrir());
  const capturas = [];
  try {
    if (tipo === "ui") {
      const lista = extra === "todos" ? DISPOSITIVOS : [extra || "pc"];
      for (const d of lista) {
        const r = await s.luau(`return require(${KIT}.UICheck).show(${JSON.stringify(nombre)}, ${JSON.stringify(d)})`);
        if (!r.startsWith("mounted")) throw new Error(r);
        // Solo el marco del dispositivo: lado-a-lado.py recorta «ruta#ancho,alto» (fracciones de la vista).
        const recorte = (r.match(/crop=([\d.]+,[\d.]+)/) || [])[1];
        const ruta = await capturar(s, `${nombre}-${d}`);
        capturas.push(recorte ? `${ruta}#${recorte}` : ruta);
      }
      await s.luau(`require(${KIT}.UICheck).clear()`);
    } else if (tipo === "mapa" || tipo === "mapa-arriba") {
      const r = await s.luau(
        tipo === "mapa" ? `return require(${KIT}.MapCheck).cameraAt(${JSON.stringify(nombre)})` : `return require(${KIT}.MapCheck).topView()`
      );
      if (r.startsWith("no ")) throw new Error(r);
      capturas.push(await capturar(s, tipo === "mapa" ? nombre : "arriba"));
    } else {
      // Efecto delante de la cámara, congelado al principio, a la mitad y al final.
      const nivel = JSON.stringify(extra || "normal");
      // El final a 0.8 de la vida más larga: a 0.95 ya no queda casi ninguna partícula y la foto sale vacía.
      for (const momento of [0.05, 0.5, 0.8]) {
        const r = await s.luau(`
local Effects = require(${KIT}.Effects)
local cam = workspace.CurrentCamera
local donde = cam.CFrame * CFrame.new(0, 0, -14)
local emisores = Effects.play(${JSON.stringify(nombre)}, donde, ${nivel})
if #emisores == 0 then return "no hay efecto ${nombre}" end
local vida = 0
for _, e in emisores do vida = math.max(vida, e.Lifetime.Max) end
task.wait(vida * ${momento})
for _, e in emisores do e.TimeScale = 0 end
return "ok"`);
        if (r !== "ok") throw new Error(r);
        capturas.push(await capturar(s, `${nombre}-${momento}`));
        await s.luau(`for _, a in workspace.Terrain:GetChildren() do if a:IsA("Attachment") and a:FindFirstChildOfClass("ParticleEmitter") then a:Destroy() end end`);
      }
    }
  } finally {
    s.cerrar();
  }
  const carpeta = path.join(process.cwd(), ".kit", "capturas");
  fs.mkdirSync(carpeta, { recursive: true });
  const salida = path.join(carpeta, `${tipo}-${nombre || "arriba"}-${new Date().toISOString().replace(/[:.]/g, "-")}.png`);
  juntar(salida, refs, capturas, `${tipo} ${nombre || ""}`.trim());
  for (const c of capturas) fs.rmSync(c.split("#")[0], { force: true });
  console.log("captura: " + salida);
})().catch((e) => {
  console.log("captura: " + e.message);
  process.exit(1);
});
