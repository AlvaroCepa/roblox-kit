// Llama a una herramienta del MCP de Studio a través de PuenteMCP.js (que tiene que estar en marcha).
// Uso: node MCP.js <herramienta> [json-args] [archivo-codigo]
//   node MCP.js get_studio_state
//   node MCP.js execute_luau '{"datamodel_type":"Server"}' prueba.luau   (el archivo va en args.code)
//   node MCP.js screen_capture '{"capture_id":"ScreenCapture_1"}'       (guarda la imagen en la carpeta temporal)
// Si no se da studio_id, usa el primer Studio abierto.
// El puente niega multi_edit, subir o generar assets y crear o cambiar scripts con execute_luau en Edit.
const fs = require("fs");
const http = require("http");
const os = require("os");
const path = require("path");
const [, , name, json, archivo] = process.argv;

function llamar(nombre, args) {
  return new Promise((ok, mal) => {
    const req = http.request({ host: "127.0.0.1", port: 47123, path: "/call", method: "POST" }, (res) => {
      let s = "";
      res.on("data", (d) => (s += d));
      res.on("end", () => ok(JSON.parse(s)));
    });
    req.on("error", mal);
    req.end(JSON.stringify({ name: nombre, arguments: args }));
  });
}

(async () => {
  if (!name) return console.log("Uso: node MCP.js <herramienta> [json-args] [archivo-codigo]");
  const args = json ? JSON.parse(json) : {};
  if (archivo) args.code = fs.readFileSync(archivo, "utf8");
  if (!args.studio_id && name !== "list_roblox_studios") {
    const lista = await llamar("list_roblox_studios", {});
    const studios = JSON.parse(lista.result.content[0].text).studios;
    if (!studios.length) return console.log("No hay ningún Studio conectado al MCP");
    args.studio_id = studios[0].id;
  }
  const r = await llamar(name, args);
  if (r.error) return console.log("ERROR:", r.error.message || JSON.stringify(r.error));
  for (const c of r.result.content || []) {
    if (c.type === "text") console.log(c.text);
    else if (c.type === "image") {
      const ruta = path.join(os.tmpdir(), "roblox-kit-captura." + (c.mimeType || "image/png").split("/")[1]);
      fs.writeFileSync(ruta, Buffer.from(c.data, "base64"));
      console.log("imagen:", ruta);
    } else console.log(JSON.stringify(c).slice(0, 500));
  }
})().catch((e) => console.log("¿Está en marcha PuenteMCP.js?", e.message));
