---
name: puntuar-idea-roblox
description: Puntúa con dureza ideas de juegos de Roblox con un sistema calibrado con los éxitos actuales de la plataforma (Grow a Garden, Steal a Brainrot, Steal an Egg y su ola de copias…), comprobando antes si la idea ya existe y si hay una ola activa que aprovechar, más un filtro de viabilidad para desarrollarlo solo con IA. Úsala SIEMPRE que el usuario pida nota, puntuación, opinión o valoración de una idea de juego de Roblox, compare ideas o pregunte si una idea "merece la pena", aunque no nombre la skill. También con /puntuar-idea-roblox.
---

# Puntuar idea de Roblox

Sistema duro para decidir si una idea merece desarrollarse **solo con IA**. Responde a dos preguntas distintas:

1. **¿El diseño es bueno?** → la nota (7 criterios).
2. **¿Es buen momento para lanzarlo?** → el momento (si hay una ola activa y cuánto se tarda en salir).

No infles las notas para animar al usuario, pero **tampoco premies la originalidad por sí misma**: en Roblox los juegos que triunfan en una ola innovan muy poco (un verbo o un tema distinto sobre un bucle probado) y les va bien.

## Paso 0: clasificar la idea

- **Seguidor de ola:** copia el bucle de un éxito actual y cambia una o dos cosas (tema, verbo, un sistema). Ej.: «Steal an Egg pero siendo un gato y trepando».
- **Idea propia:** bucle que no sigue a ningún éxito activo.

Una **ola activa** es un líder con muchos jugadores más seguidores lanzados en las últimas 4 semanas que superan los 5.000 jugadores simultáneos. Si no se cumple, trata la idea como propia aunque se parezca a algo.

## Paso 1: comprobaciones obligatorias (antes de puntuar)

1. **¿Ya existe?** Busca 2–3 formulaciones en inglés por idea (título probable, «verbo for X», sinónimos) en el buscador de Roblox y lee la descripción de los que se parezcan. WebSearch casi nunca encuentra juegos pequeños; usa las APIs públicas (PowerShell, Python no está instalado):
   ```powershell
   # Buscar juegos (name, playerCount, universeId)
   Invoke-RestMethod ("https://apis.roblox.com/search-api/omni-search?pageType=all&sessionId=x1&searchQuery=" + [uri]::EscapeDataString("climb for eggs"))
   # Descripción, visitas, fecha de creación (hasta ~50 ids por llamada; si da "Too many requests", espera y reintenta en lotes pequeños)
   Invoke-RestMethod "https://games.roblox.com/v1/games?universeIds=ID1,ID2"
   # Listas de Descubrir (Top Trending, Up-and-Coming, Top Playing Now)
   Invoke-RestMethod "https://apis.roblox.com/explore-api/v1/get-sorts?sessionId=x1&device=computer&country=all"
   ```
   Si el usuario dice que algo ya existe, créele aunque la búsqueda no lo encuentre.
2. **¿Cómo funciona de verdad el juego de referencia?** Compruébalo en guías de jugadores, no en la descripción oficial ni en artículos de prensa. (Ejemplo: Steal an Egg es PvE —robas huevos a guardianes, no a otros jugadores— aunque su descripción diga lo contrario.)
3. **¿Está viva la ola?** Mira los jugadores actuales del líder y de los seguidores más recientes (fecha de creación + jugadores ahora).

## Criterios (de 0 a 10)

| Criterio | Peso | Pregunta |
|---|---|---|
| Comprensión | 15 % | ¿Se entiende en cinco segundos viendo a alguien jugar, o solo por el título y la miniatura? |
| Bucle | 15 % | ¿La acción básica da gusto repetirla cientos de veces? |
| Progresión | 15 % | ¿Siempre hay algo más raro o mejor que perseguir? |
| Social | 15 % | ¿Los demás jugadores cambian tu partida? (robar, intercambiar, presumir, cooperar) |
| Volver | 15 % | ¿Hay motivos concretos para entrar mañana? (progreso sin conectarte, eventos, reposiciones) |
| Viralidad | 15 % | ¿Produce momentos que se recortan para TikTok o YouTube, o un meme? |
| Actualizaciones | 10 % | ¿Es barato sacar contenido nuevo a menudo? |

### Anclas
- **10:** al nivel del mejor de Roblox en ese criterio (por ejemplo, Volver de Grow a Garden o Social de Steal a Brainrot).
- **8:** claramente bueno, con una mecánica concreta que lo sostiene.
- **6:** está, pero es genérico o secundario.
- **4:** casi no está, o es débil.
- **2 o menos:** no existe.

### Lo que se ha visto que funciona (úsalo al puntuar)
- **Comprensión:** el título es «Verbo + cosa» («Steal an Egg», «Kick a Lucky Block», «Get Your Driver's License!») o «+1 estadística + acción» («+1 Stone Skipping»). Si el título no dice qué haces, Comprensión ≤ 7.
- **Bucle:** acciones cortas (un ciclo de menos de un minuto). Las escaladas o recorridos largos cansan: bájalo un punto si el trayecto domina el ciclo.
- **Progresión:** coleccionar **criaturas** (mascotas, brainrots, animales) con rareza, tamaño y mutaciones engancha mucho más que coleccionar **objetos** (ovillos, piedras, monedas). Objetos sin criaturas: máximo 7, salvo que algo «salga» de ellos.
- **Social:** no es obligatorio para triunfar (Steal an Egg es PvE y llegó a 14 millones). Puntúa lo que hay, pero no lo trates como requisito.
- **Volver:** lo que funciona hoy: ingresos sin conectarte, cosas que crecen o eclosionan en tiempo real, actualizaciones fijas cada sábado y eventos con horario (Admin Abuse, clima). Los juegos de un solo turno o historia (ola Anomaly) pegan un pico y caen: Animal Hospital pasó de 1,3 millones a −90 %. El algoritmo de Roblox (desde el 20/08/2026) premia la retención y la monetización.
- **Viralidad:** catástrofes que provocas y de las que huyes, ragdoll y salir volando, estampidas de todo el servidor, revelar qué sale de algo, giro de «tierno» a «terror».

## Penalizaciones (después de la media ponderada)

- **Veto:** si algún criterio queda en 4 o menos, la nota máxima es 6,0.
- **Comprensión débil:** si Comprensión está por debajo de 7, la nota máxima es 6,5.
- **Duplicado:** −1,0 si ya existe un juego con el **mismo verbo y el mismo tema** y más de 1.000 jugadores. Si existe pero está muerto (menos de ~200), no penalices, pero dilo.
- **Saturación (solo ideas propias o olas muertas):** −1,0 si el género ya tiene un líder claro, no hay ola activa y la diferencia es solo de tema o aspecto. **A un seguidor de una ola activa no se le penaliza por parecerse al líder**: es justo lo que funciona.
- **Depende de la ejecución:** −0,5 si la gracia depende de arte, animación o sonido de calidad; −1,0 si depende mucho.
- **Alcance:** −0,5 si para que tenga sentido necesita mucho contenido hecho a mano desde el primer día, o (en seguidores) si añade más de un sistema nuevo grande sobre el bucle del líder antes de poder lanzarse.

## Momento (de 0 a 10, filtro aparte; obligatorio en seguidores de ola)

| Momento | Situación |
|---|---|
| 9–10 | Ola en pico: seguidores de las últimas 2 semanas superan 5.000 jugadores y se puede lanzar en ≤ 2 semanas. |
| 7–8 | Ola fuerte, pero los seguidores más recientes rinden menos, o el lanzamiento tardaría 2–4 semanas. |
| 5–6 | Ola bajando (líder muy por debajo de su pico, seguidores nuevos por debajo de 1.000) o lanzamiento en 4–6 semanas. |
| ≤ 4 | Ola muerta o más de 6 semanas para lanzar. |

- Las fechas de temporada (Halloween, Navidad) suben el momento si se puede lanzar antes de la fecha, y lo hunden después.
- Hay estudios que sacan una variante nueva cada pocos días con la misma plantilla. En una ola, **la velocidad importa más que la originalidad**: cualquier verbo libre hoy puede estar cogido en una semana.
- La forma más rápida de lanzar es tener una **base reutilizable** (el bucle del género ya hecho) y cambiar solo tema o verbo en cada variante.
- Para ideas propias, el momento es informativo y no cambia el veredicto.

## Viabilidad con IA (de 0 a 10, filtro aparte)

La IA hace bien: sistemas en Luau, datos y tablas en volumen, generación por procedimiento, mallas sencillas generadas, neón, luces y partículas, interfaz plana hecha por código, iluminación y ambiente, animaciones simples por código (tweens, sin esqueleto).

La IA hace mal: criaturas o personajes con esqueleto y animaciones complejas, sonido y música, arte ilustrado (interfaz, iconos detallados, miniaturas), físicas de vehículos muy pulidas, mucho contenido artesanal, combate con sensación de golpe y controles de movimiento propios (agarre a paredes, escalada libre).

Antes de bajar la nota, busca el atajo nativo: escalada con TrussPart escondidas en muebles o cortinas, avatar R15 con accesorios en vez de un esqueleto propio, criaturas de bloques animadas con tweens. Si el atajo existe y sirve, puntúa con él y dilo.

Puntúa según la parte del juego que caiga en "hace mal" y lo central que sea para la diversión.

## Veredicto

### Idea propia
| Nota final | IA | Veredicto |
|---|---|---|
| 9 o más | 8 o más | **Adelante**: prototipo ya. |
| 8,5 – 8,9 | 8 o más | **Prototipo de prueba**: validar el bucle antes de comprometerse. |
| 7,5 – 8,4 | cualquiera | **Rediseñar**: no se desarrolla así. |
| menos de 7,5, o IA menor que 8 | — | **Descartar** o cambiar de enfoque. |

### Seguidor de ola activa
| Nota final | IA | Momento | Veredicto |
|---|---|---|---|
| 7,5 o más | 8 o más | 8 o más | **Adelante rápido**: lanzar la versión mínima cuanto antes y añadir sistemas como actualizaciones. |
| 7,5 o más | 8 o más | 6–7 | **Solo si sale ya**: recortar a lo mínimo o reutilizar una base existente. |
| menos de 7,5, o IA menor que 8, o Momento 5 o menos | — | — | **Descartar** o cambiar de ola. |

El umbral es más bajo para seguidores porque el éxito de una ola lo pone el líder: copias con notas de diseño normales sacan 5.000–75.000 jugadores si llegan a tiempo.

## Calibración (juegos reales; estimaciones, sin penalizaciones)

### Líderes
| Juego | Comp | Bucle | Prog | Social | Volver | Viral | Act | Nota | IA |
|---|---|---|---|---|---|---|---|---|---|
| Grow a Garden | 10 | 9 | 10 | 9 | 10 | 9 | 10 | 9,5 | 9 |
| Steal a Brainrot | 10 | 9 | 9 | 10 | 9 | 10 | 9 | 9,4 | 7 |
| Steal an Egg | 10 | 9 | 9 | 7 | 9 | 9 | 10 | 8,9 | 8 |
| Adopt Me | 9 | 7 | 9 | 10 | 9 | 7 | 8 | 8,4 | 5 |
| Ride A Pet | 9 | 8 | 9 | 7 | 9 | 8 | 9 | 8,4 | 7 |
| 99 Nights in the Forest | 9 | 8 | 7 | 9 | 7 | 9 | 7 | 8,0 | 6 |
| Fisch | 9 | 8 | 10 | 6 | 8 | 7 | 7 | 7,9 | 6 |
| Doors | 9 | 9 | 5 | 8 | 6 | 10 | 5 | 7,5 | 4 |
| Blox Fruits | 7 | 8 | 10 | 7 | 8 | 7 | 4 | 7,4 | 3 |
| Animal Hospital (Anomaly) | 9 | 7 | 5 | 8 | 5 | 10 | 7 | 7,3 | 6 |
| Tower of Hell | 10 | 8 | 5 | 7 | 6 | 7 | 9 | 7,3 | 9 |

Doors y Blox Fruits triunfaron con ideas de 7,5 o menos gracias a la ejecución, que es justo lo que la IA no aporta. Animal Hospital muestra el otro límite: viralidad máxima sin Volver da un pico enorme y una caída del 90 %.

### Seguidores de la ola Steal an Egg (jugadores simultáneos a 10/10/2026)
| Juego | Cambio sobre el líder | Nota aprox. | Jugadores |
|---|---|---|---|
| Break and Steal an Egg | + romper el huevo con pico | 8,5 | 73.000 |
| Steal Animal Egg | + robo entre jugadores y comida | 8,4 | 22.000 |
| Drill for Eggs | verbo: taladrar hacia abajo | ~8 | 18.000 |
| Steal an Clown Egg | solo tema | ~7,8 | 9.700 |
| Shrink For Eggs | verbo poco claro (encogerse) | 7,2 | 900 |

Cambios pequeños bastan; lo que hunde a un seguidor es un verbo que no se entiende, un bucle más lento o llegar tarde.

## Mercado actual (revisar si tiene más de un mes; actualízalo con las APIs)

A 10/10/2026:
- **Olas activas:** «Steal a…/…for Eggs» (líder Steal an Egg, 1,4 M; ~85 copias, unas 20 por encima de 5.000), «+1 estadística» (+1 Speed Keyboard Escape 2,6 M, +1 Stone Skipping 51.000, +1 Loot To Forge 35.000), trabajo tierno que se vuelve terror o «Anomaly» (Animal Hospital, 7 Days Cat-Sitting 37.000, Sell Fries! 26.000), trabajos cotidianos con humor (Get Your Driver's License! 28.000 en 12 días, Renovate A House, Clean Everything, Melt All The Ice, Makeup Mania! 61.000) y memes de personaje (Verity, Kukirin).
- **Restricción:** Roblox limitó los juegos que muestran vídeos generados por IA mientras juegas (tras la cinta de Steal an Egg, MassivelyOP, 29/08/2026). No propongas esa mecánica.

## Formato de respuesta

En español y conciso:

1. **Tipo** (seguidor de ola o idea propia) y **existencia**: qué juegos parecidos hay, con jugadores actuales.
2. Una tabla con los 7 criterios: nota y justificación de una línea cada uno, nombrando la mecánica concreta.
3. La media ponderada, cada penalización aplicada con su motivo y la **nota final**.
4. La viabilidad con IA, en una línea, con lo que la IA haría mal y el atajo nativo si lo hay.
5. El **momento** (obligatorio en seguidores), en una línea.
6. El **veredicto** de la tabla que corresponda.
7. Los **dos o tres cambios** que más subirían la nota, con cuánto la subiría cada uno. Que sean cambios que la IA pueda hacer y, en seguidores, que no retrasen el lanzamiento (si retrasan, propónlos como actualizaciones).

Si el usuario compara varias ideas, añade una tabla final ordenada por nota.
