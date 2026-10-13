---
name: juego-nuevo
description: Crea la carpeta y el repo de un juego de Roblox nuevo desde la plantilla de roblox-kit (src/server|client|shared, cargador, Rokit, Wally, Zap, pruebas, CI) y deja que pase comprobar y la CI desde el primer momento. Úsala siempre que el usuario quiera empezar un juego nuevo, crear el repo de un juego, pasar una idea aprobada a juego o "montar la plantilla", aunque no nombre la skill.
---

# Juego nuevo

La plantilla está en `plantilla/` del plugin y el script en `kit/juego-nuevo.luau`. La carpeta del plugin
(`<kit>`) está dos niveles por encima de la carpeta de esta skill.

**Regla:** no se toca nada de GitHub (crear repo, invitar, secretos) sin el sí del usuario: es público hacia fuera.

## Pasos
1. **Nombre y carpeta.** Pregunta el nombre del juego (en inglés, es el que ve el jugador) y dónde va la
   carpeta si no lo dice. La carpeta debe no existir o estar vacía.
2. **Crear** (desde cualquier carpeta con `rokit.toml`, por ejemplo `<kit>/plantilla`, para que Rokit dé Lune):
   ```
   lune run "<kit>/kit/juego-nuevo.luau" "<carpeta>" --nombre "<Nombre>"
   ```
3. **Herramientas y paquetes**, en la carpeta nueva:
   ```
   rokit install --no-trust-check
   lune run "<kit>/kit/paquetes.luau"
   ```
4. **Comprobar:** `lune run "<kit>/kit/comprobar.luau"` debe dar `comprobar: bien`. Si no, arréglalo antes de
   seguir: la plantilla recién creada tiene que pasar siempre (si falla, es un fallo del plugin: propón el arreglo
   al usuario como issue `mejora` en AlvaroCepa/roblox-kit).
5. **Git:** `git init -b main`, email del repo = el noreply de GitHub del usuario
   (`git config user.email "<id>+<usuario>@users.noreply.github.com"`, sácalo con `gh api user`), primer commit
   con todo (incluido `wally.lock`).
6. **GitHub, con su sí:** repo **privado** `AlvaroCepa/<nombre-en-minúsculas>`, push, y Darío como colaborador
   si el usuario lo dice. La CI corre sola en el primer push.
7. **Clave de la CI** (paso del usuario, la clave nunca pasa por el chat): crea en la cuenta bot de Roblox una
   clave como las de los PCs pero **sin assets**, y la guarda en el repo con
   `gh secret set ROBLOX_API_KEY --repo AlvaroCepa/<repo>` (lo lanza él en su terminal y pega la clave cuando
   lo pide). Sin ella, la CI avisa y se salta la prueba en la nube.
8. **Prueba en la nube** (sube a «Pruebas» guardado, nunca publicado):
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<kit>/kit/probar-nube.ps1"`.

Termina con un resumen corto: dónde está, qué pasa ya (comprobar, CI, nube) y qué queda pendiente.

## Qué trae la plantilla
- Un sistema de ejemplo pequeño (monedas): un dato, una regla, dos remotos y sus pruebas. Sirve de modelo:
  copia su forma para lo nuevo y bórralo cuando ya no haga falta.
- `CLAUDE.md` corto con las reglas del juego y los comandos. Lo general va en las skills del plugin.
- ProfileStore fijado en `src/server/Vendor/` (sin conectar todavía) y Trove por Wally.
- `.claude/settings.json` con las herramientas de Studio que solo leen ya permitidas.
