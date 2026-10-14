// Cliente de un solo uso del MCP oficial de Studio, para los scripts del plugin (guardar-mapa, capturas,
// comprobadores): arranca %LOCALAPPDATA%\Roblox\mcp.bat, llama a las herramientas y se cierra. Así lo
// pesado (el mapa en base64, las imágenes) no pasa por el chat ni gasta tokens.
// Como se salta los hooks de Claude Code, aplica las mismas reglas que el puente: niega lo arriesgado.
const { spawn } = require("child_process");
const path = require("path");
const { motivoParaNegar } = require("../puente/reglas");

function conectar() {
  const bat = path.join(process.env.LOCALAPPDATA || "", "Roblox", "mcp.bat");
  const hijo = spawn("cmd.exe", ["/c", bat], { stdio: ["pipe", "pipe", "pipe"], windowsHide: true });
  const esperando = new Map();
  let siguiente = 1;
  let resto = "";
  let errores = "";
  hijo.stderr.on("data", (d) => (errores += d.toString("utf8")));
  hijo.stdout.on("data", (d) => {
    resto += d.toString("utf8");
    let i;
    while ((i = resto.indexOf("\n")) >= 0) {
      const linea = resto.slice(0, i).trim();
      resto = resto.slice(i + 1);
      if (!linea) continue;
      let msg;
      try { msg = JSON.parse(linea); } catch { continue; }
      if (msg.id !== undefined && esperando.has(msg.id)) {
        esperando.get(msg.id)(msg);
        esperando.delete(msg.id);
      }
    }
  });
  const salida = new Promise((_, mal) =>
    hijo.on("exit", (c) => mal(new Error(`el MCP de Studio se cerró (código ${c}). ${errores.slice(-300)}`)))
  );
  salida.catch(() => {}); // al cerrar a propósito no es un error
  function pedir(method, params, segundos = 120) {
    const id = siguiente++;
    const respuesta = new Promise((ok) => esperando.set(id, ok));
    hijo.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
    const tiempo = new Promise((_, mal) =>
      setTimeout(() => mal(new Error(`sin respuesta del MCP de Studio en ${segundos} s (${method})`)), segundos * 1000)
    );
    return Promise.race([respuesta, salida, tiempo]);
  }
  return { hijo, pedir };
}

// Abre la conexión, elige el Studio (el primero, o el que tenga `nombre` en su título) y devuelve `llamar`.
async function abrir(nombre) {
  const { hijo, pedir } = conectar();
  const ini = await pedir("initialize", {
    protocolVersion: "2026-07-28",
    capabilities: {},
    clientInfo: { name: "roblox-kit", version: "1.0" },
  }, 30);
  if (ini.error) throw new Error("initialize: " + JSON.stringify(ini.error));
  hijo.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

  async function llamarCrudo(herramienta, args, segundos) {
    const motivo = motivoParaNegar(herramienta, args);
    if (motivo) throw new Error("negado por roblox-kit: " + motivo);
    const r = await pedir("tools/call", { name: herramienta, arguments: args }, segundos);
    if (r.error) throw new Error(`${herramienta}: ${r.error.message || JSON.stringify(r.error)}`);
    return r.result;
  }
  const lista = await llamarCrudo("list_roblox_studios", {}, 30);
  const studios = JSON.parse(lista.content[0].text).studios || [];
  const studio = studios.find((s) => !nombre || String(s.name).includes(nombre)) || null;
  if (!studio) {
    hijo.stdin.end();
    throw new Error(studios.length ? `no hay un Studio con «${nombre}» en el nombre` : "no hay ningún Studio conectado al MCP (¿Studio abierto con el MCP activado?)");
  }
  return {
    studio,
    // Llama a una herramienta en ese Studio y devuelve su contenido (texto e imágenes).
    async llamar(herramienta, args = {}, segundos = 120) {
      const r = await llamarCrudo(herramienta, { ...args, studio_id: studio.id }, segundos);
      if (r.isError) throw new Error(`${herramienta}: ${(r.content || []).map((c) => c.text).join(" ")}`);
      return r.content || [];
    },
    // execute_luau y su texto de vuelta.
    async luau(codigo, modo = "Edit", segundos = 120) {
      const c = await this.llamar("execute_luau", { code: codigo, datamodel_type: modo }, segundos);
      return c.filter((x) => x.type === "text").map((x) => x.text).join("\n");
    },
    // Cierra la entrada (StudioMCP termina solo) y, por si acaso, el árbol entero (cmd.exe no mata a sus hijos).
    cerrar() {
      hijo.stdin.end();
      setTimeout(() => {
        if (hijo.exitCode !== null) return;
        if (process.platform === "win32") {
          spawn("taskkill", ["/T", "/F", "/PID", String(hijo.pid)], { stdio: "ignore", windowsHide: true });
        } else hijo.kill();
      }, 1500).unref();
    },
  };
}

module.exports = { abrir };
