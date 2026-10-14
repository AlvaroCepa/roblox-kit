# {{nombre}}

Juego de Roblox hecho con el plugin **roblox-kit** (lo mantiene solo Álvaro; las mejoras del plugin van como
issues en AlvaroCepa/roblox-kit). Qué juego es: se escribe en la fase de concepto.

## Estructura
- `src/server` (nunca llega al jugador), `src/client`, `src/shared` (lo puede leer un tramposo: nada de reglas de servidor).
- `src/shared/Data`: números y textos. Todo lo que ve el jugador, en inglés y solo aquí.
- `src/shared/Rules`: lógica pura, sin `game` ni servicios (lo vigila `comprobar`).
- `src/*/Systems`: un módulo por sistema con `init()` (prepara y conecta, sin esperar) y `start()`.
  Los arranca `src/shared/Kit/Loader.luau`, copia del plugin: no se edita aquí.
- Remotos: solo en `net.zap`; después, `zap` en la raíz (regenera `src/shared/Net`, que no se edita a mano).
- Código y nombres en inglés; comentarios y documentación en español. Archivos `.luau`, `--!strict`.
- `src/server/Vendor/ProfileStore.luau`: copia fijada del oficial, no se edita.
- `src/shared/Kit/`: módulos del kit, copias del plugin (cargador, UI, Screens, List, Markers, Effects, Sounds,
  Motion, Animations, comprobadores). No se editan aquí.
- `src/shared/Data/Style.luau`: hoja de estilo (UI, efectos, sonido, animación). Todo lo que se ve o se oye sale de aquí.
- `src/shared/Assets/`: ids generados por Asphalt; en el código, siempre `Asset.get("ui/...")`, nunca un id suelto.
- `assets/` (imágenes, sonidos, animaciones y modelos que se suben al grupo), `map/` (trozos del mapa, ficha en
  `Data/Map.luau`), `models/` (modelos 3D montados), `bloques/` y `Estado.md` (plan del juego, skill `jefa`).
- Cada oficio tiene su skill en el plugin (ui, mapa, modelos-3d, vfx, sonido, animacion, jefa, trabajo-entre-dos):
  cárgala antes de tocar lo suyo.
- Lo general de un oficio va en las skills del plugin. Lo propio de este juego que dependa de una carpeta, en
  `.claude/rules/` (cada archivo con su frontmatter `paths`).

## Pruebas
- En `tests/`, como espejo de `src`. Solo reglas y datos, no una por módulo.
- `X.spec.luau` corre en Lune: carga con `require("@src/shared/...")` y cada prueba recibe `expect`.
- `X.cloud.spec.luau` solo corre en «Pruebas» con `probar-nube`: carga los módulos por instancia.

## Comandos
El hook de inicio de sesión da la ruta del plugin (`<kit>`). Desde la raíz del juego:
- Todo: `lune run "<kit>/kit/comprobar.luau"` (el hook de Stop ya lo pasa solo cuando cambia código).
- Paquetes de Wally: `lune run "<kit>/kit/paquetes.luau"`.
- En la nube: `powershell -NoProfile -ExecutionPolicy Bypass -File "<kit>/kit/probar-nube.ps1"`.
- Copia local para Studio: `lune run "<kit>/kit/montar.luau"` (después, `rojo serve`).
- Guardar el mapa y los modelos de Studio: `node "<kit>/kit/guardar-mapa.js"`.
- Capturas al lado de referencias: `node "<kit>/kit/captura.js" ui|mapa|vfx ...`.
- Subir assets al grupo (pregunta antes): `powershell -NoProfile -ExecutionPolicy Bypass -File "<kit>/kit/subir-assets.ps1"`.
- Comprobadores en Studio (modo Edit): `require(game.ReplicatedStorage.Shared.Kit.UICheck).run()` y `...MapCheck).run()`.
