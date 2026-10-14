---
name: jefa
description: Lleva el plan de un juego de Roblox de la idea al lanzamiento y sus actualizaciones (fases idea, concepto, núcleo jugable, lista de bloques, bloques, pulido, lanzamiento y actualizaciones; Estado.md; un bloque en 5 pasos; modo «adoptar» para juegos ya empezados). Úsala SIEMPRE que se pregunte qué toca ahora en un juego, por dónde vamos, cuál es el siguiente bloque, cuando se quiera empezar o cerrar un bloque, pasar de fase, escribir un concepto o una lista de bloques, preparar el lanzamiento, revisar los números del juego, o adoptar un juego existente como Steal an Egg.
effort: high
---

# Skill jefa

**Álvaro es quien desarrolla.** Esta skill **lleva el plan, no hace el juego**: dice qué toca y por qué, prepara
cada bloque y hace lo mecánico (cargar las skills de cada oficio, comprobar, probar). **Las decisiones del juego
(cómo se siente, ritmo, números, qué entra) son de Álvaro.** Solo se carga el detalle de la fase en la que estáis.

## Dónde vive todo (en git, para que Darío también pueda)
- **Idea y concepto:** repo privado `AlvaroCepa/ideas-roblox`, una carpeta por idea con su nota de puntuación,
  `Concepto.md` y `Estado.md`. Las ideas descartadas no crean repo.
- Al aprobar el concepto, la skill `juego-nuevo` crea el repo del juego y **mueve allí la carpeta entera**.
- `Estado.md` en la raíz del juego (plantilla en `plantillas/Estado.md`): **corto**. La primera línea tiene siempre
  el mismo formato y el hook de inicio la enseña. Las decisiones NO van aquí: van en el concepto o en su bloque.
- Bloques: `bloques/Lista.md` (una línea por bloque) y `bloques/<bloque>.md` (el detalle, al abrirlo).

## Fases (se puede saltar o volver atrás; avisa solo si falta algo importante)
1. **Idea** → skill `puntuar-idea-roblox`. Detalle: `referencias/fase-1-idea.md`.
2. **Concepto** (una página: bucle, monetización, imagen de estilo, qué entra en la v1 y cuánto falta para la v1;
   si aprovecha una ola, v1 mínima y rápida) → `referencias/fase-2-concepto.md`.
3. **Núcleo jugable** (opcional: el bucle hecho rápido y feo para ver si engancha; recomienda hacerlo si la
   mecánica es nueva y saltarlo si ya está probada por otro juego; decide Álvaro) → `referencias/fase-3-nucleo.md`.
4. **Lista de bloques** (en orden, una línea cada uno) → `referencias/fase-4-lista.md`.
5. **Bloques**, uno a uno (abajo) → `referencias/fase-5-bloques.md`.
6. **Pulido** (lo juegan Darío y amigos; fallos como issues del repo del juego) → `referencias/fase-6-pulido.md`.
7. **Lanzamiento** (lista de comprobación; **se publica a mano, solo Álvaro, solo desde main**) → `referencias/fase-7-lanzamiento.md`.
8. **Actualizaciones** (números del panel de Roblox → mejoras como bloques) → `referencias/fase-8-actualizaciones.md`.
Juego empezado antes de este sistema: **modo adoptar** → `referencias/adoptar.md` (solo escribe archivos).

## Un bloque (una función jugable entera, p. ej. «comprar huevo»)
1. **Abrir:** di qué toca y por qué (Álvaro puede elegir otro). Apunta el dueño en `Estado.md`. Rama propia
   `bloque/<nombre>` (skill `trabajo-entre-dos`).
2. **Hablarlo:** explica cómo lo harías, escribe el detalle en `bloques/<bloque>.md` (datos, pantallas, remotos,
   assets; plantilla `plantillas/Bloque.md`) y **pregunta lo que solo decide Álvaro**: cómo se siente, ritmo, números.
3. **Hacerlo a trozos**, con Álvaro delante, cargando la skill de cada oficio que toque. Pasa la escalera de
   pruebas: hooks y `comprobar` → Lune → `probar-nube` → (si hace falta) Play corto para cazar errores.
4. **Probarlo Álvaro** en Studio. Ajusta lo que diga, sobre todo los números de `Data`. Nunca opines sobre si se
   siente bien: eso lo juzga él.
5. **Cerrar cuando Álvaro lo diga:** commit, PR y fusión (CI en verde), `Estado.md` al día, reglas propuestas (abajo)
   y **una línea de mejora** del plugin (abajo).

## Al cerrar cada bloque
- **Reglas:** si algo falló y se arregló, propón la regla (texto, porqué, en qué skill). Nunca edites una skill del
  plugin por tu cuenta: si Álvaro dice que sí, va al repo del plugin; si es Darío, como issue en AlvaroCepa/roblox-kit.
- **Una línea de mejora:** qué fue lento, qué se repitió o qué se hizo a mano y podría hacer un script. Hazla con un
  subagente barato (modelo Sonnet o Opus con esfuerzo bajo) y, si vale, que acabe como issue `mejora` del plugin
  (sin nombres de juegos ni datos privados: el repo es público).
