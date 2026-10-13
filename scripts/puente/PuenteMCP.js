// Para la IA, cuando Claude Code no puede conectar con el MCP de Studio (p. ej. «protocol version is not supported»):
// arranca el StudioMCP oficial de Roblox por su cuenta y deja sus herramientas en http://127.0.0.1:47123.
// Uso: node PuenteMCP.js (en segundo plano), y luego MCP.js para llamar a las herramientas.
//
// El puente se salta los hooks de Claude Code, así que aquí no se puede pedir permiso: lo arriesgado se NIEGA.
// Solo sirve para probar (Play, consola, capturas, leer el árbol).
const { spawn } = require("child_process");
const http = require("http");
const path = require("path");

// Misma regla que el freno de roblox-kit (hooks/freno.ps1), pero negando en vez de preguntar.
function motivoParaNegar(nombre, args) {
  if (nombre === "multi_edit") return "multi_edit edita o crea scripts en Studio; el código vive en el repo y lo pasa Rojo";
  if (nombre === "upload_image" || nombre === "store_image" || nombre.startsWith("generate_"))
    return nombre + " sube o crea assets a nombre de quien tiene Studio abierto; hazlo desde Claude Code, que pide permiso";
  if (nombre === "execute_luau" && args && args.datamodel_type === "Edit") {
    const codigo = String(args.code || "");
    if (
      /\.Source\s*=(?!=)/.test(codigo) ||
      /\[\s*["']Source["']\s*\]\s*=(?!=)/.test(codigo) ||
      /UpdateSourceAsync/.test(codigo) ||
      /Instance\.new\s*\(\s*["'](Script|LocalScript|ModuleScript)["']/.test(codigo)
    )
      return "este execute_luau en Edit cambia o crea scripts en Studio; el código vive en el repo y lo pasa Rojo";
  }
  return null;
}

const bat = path.join(process.env.LOCALAPPDATA, "Roblox", "mcp.bat");
const hijo = spawn("cmd.exe", ["/c", bat], { stdio: ["pipe", "pipe", "pipe"] });
hijo.stderr.on("data", (d) => process.stderr.write("[mcp] " + d));
hijo.on("exit", (c) => { console.log("StudioMCP salió", c); process.exit(1); });

let siguiente = 1;
const esperando = new Map();
let resto = "";
hijo.stdout.on("data", (d) => {
  resto += d.toString("utf8");
  let i;
  while ((i = resto.indexOf("\n")) >= 0) {
    const linea = resto.slice(0, i).trim();
    resto = resto.slice(i + 1);
    if (!linea) continue;
    let msg;
    try { msg = JSON.parse(linea); } catch { console.log("no JSON:", linea.slice(0, 200)); continue; }
    if (msg.id !== undefined && esperando.has(msg.id)) {
      esperando.get(msg.id)(msg);
      esperando.delete(msg.id);
    } else {
      console.log("aviso:", linea.slice(0, 300));
    }
  }
});

function pedir(method, params) {
  const id = siguiente++;
  return new Promise((ok) => {
    esperando.set(id, ok);
    hijo.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  });
}

(async () => {
  const ini = await pedir("initialize", {
    protocolVersion: "2026-07-28",
    capabilities: {},
    clientInfo: { name: "puente-roblox-kit", version: "1.0" },
  });
  console.log("initialize:", JSON.stringify(ini).slice(0, 300));
  hijo.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

  http.createServer((req, res) => {
    let cuerpo = "";
    req.on("data", (c) => (cuerpo += c));
    req.on("end", async () => {
      try {
        let r;
        if (req.url === "/tools") r = await pedir("tools/list", {});
        else {
          const { name, arguments: args } = JSON.parse(cuerpo);
          const motivo = motivoParaNegar(String(name), args || {});
          if (motivo) {
            res.writeHead(403, { "Content-Type": "application/json" });
            return res.end(JSON.stringify({ error: { message: "Negado por el puente de roblox-kit: " + motivo } }));
          }
          r = await pedir("tools/call", { name, arguments: args || {} });
        }
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(r));
      } catch (e) {
        res.writeHead(500);
        res.end(String(e));
      }
    });
  }).listen(47123, "127.0.0.1", () => console.log("puente en 47123"));
})();
