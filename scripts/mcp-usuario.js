// Imprime en JSON los MCP configurados a nivel de usuario en ~/.claude.json: { nombre: "comando args" }.
// Lo usa diagnostico.ps1. Se lee con Node porque ~/.claude.json puede tener claves repetidas que PowerShell 5.1 no acepta.
const fs = require("fs");
const path = require("path");
const os = require("os");
let servidores = {};
try {
  const j = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude.json"), "utf8"));
  for (const [nombre, s] of Object.entries(j.mcpServers || {})) {
    servidores[nombre] = [s.command || s.url || "", ...(s.args || [])].join(" ");
  }
} catch {}
console.log(JSON.stringify(servidores));
