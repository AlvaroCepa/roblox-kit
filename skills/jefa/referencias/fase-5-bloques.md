# Fase 5: bloques

Los 5 pasos están en el SKILL.md. Más detalle:
- **Elegir el siguiente:** el primero sin hacer de la lista, salvo que dependa de otro sin hacer o que Álvaro quiera otro.
  Si Darío lleva uno, no lo toques: mira el dueño en `Estado.md`.
- **El detalle del bloque** (`bloques/<bloque>.md`): qué ve y hace el jugador, datos nuevos en `Data` (con de dónde sale
  cada número), remotos en `net.zap`, pantallas (con ficha corta), assets (modelos, iconos, efectos, sonidos) y qué
  pruebas lleva (solo reglas y datos). Las preguntas para Álvaro, arriba del todo, hasta que las conteste.
- **Durante el bloque**, carga la skill de cada oficio cuando toque (ui, mapa, modelos-3d, vfx, sonido, animacion).
- **Escalera de pruebas** antes de enseñarle nada: comprobar (lo lanza el hook) → Lune → probar-nube (el hook lo pide)
  → comprobadores de UI y mapa en Studio si cambiaron (el hook los pide) → Play corto solo si hace falta (cliente y
  servidor hablando, UI que reacciona, físicas, toques). Al acabar un Play, di qué comprobaste y qué salió en consola.
- **Cerrar:** PR con la CI en verde, fusionar (skill `trabajo-entre-dos`), `Estado.md` al día, regla propuesta si hubo
  fallo y la línea de mejora del plugin.
