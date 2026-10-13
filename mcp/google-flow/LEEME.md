# google-flow (copia propia parcheada)

Copia de `google-flow-browser-mcp` 1.0.0 (MIT, github.com/hitjcl/google-flow-mcp; su licencia está en `LICENSE`).
No va en el `.mcp.json` del plugin: cada uno inicia sesión en Google Flow con su cuenta. `scripts/diagnostico.ps1`
la copia a `~/.claude/mcp-servers/google-flow`, instala sus dependencias con `npm install` (versiones fijadas en
`package.json`) y la registra en Claude Code con `node .../dist/src/index.js`, así no se actualiza sola.

Parche del 2026-10-12 (solo `dist/src/flow-adapter.js`; el original está al lado como `flow-adapter.original.js`):
- Flow se mudó de `labs.google/fx/tools/flow` a `flow.google.com`; proyectos ahora en `/project/<uuid>`.
- Las miniaturas ya no tienen enlace: se leen `img|video[data-media-id]` y se abren con clic (`/edit/<id>`).
- Botón de descarga "Descargar contenido multimedia"; menú "1K Tamaño original" (2K/4K son mejoradas).
- La caja de la petición es un ProseMirror sin etiqueta: se expone como "Prompt".
- "Iniciar generación" cuenta como acción que gasta créditos (pide permiso).
- Chrome se abre maximizado. Mensajes de login en español.

Cómo usar Flow ahora: el modo "Agente" viene activado por defecto; para generar directo hay que desactivarlo
(botón "Agente"), y entonces aparece "Activador de ajustes" (Imagen, 1:1, Nano Banana 2.1, x1).
Con eso marca "0 puntos" (gratis). Descargar "1K Tamaño original". Los vídeos gastan créditos: no se usan.
