// Lo que los programas del plugin que hablan con Studio sin Claude Code (el puente y scripts/studio) NIEGAN.
// Es la misma regla que el freno de roblox-kit (hooks/freno.ps1), pero negando en vez de preguntar:
// fuera de Claude Code nadie puede aprobar nada.
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

module.exports = { motivoParaNegar };
