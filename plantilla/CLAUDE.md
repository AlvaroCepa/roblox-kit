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
