---
name: trabajo-entre-dos
description: Cómo trabajan Álvaro y Darío a la vez en un juego de Roblox con roblox-kit (main es el único juego de verdad, una rama corta por bloque, PR con la CI en verde, quién fusiona, choques de git, cada uno su copia local sin Team Create, trozos del mapa de uno en uno, revisiones de lo compartido, publicar). Úsala SIEMPRE que haya que crear una rama, hacer commit, push, PR o fusionar, traer cambios del otro (pull), resolver un choque de git, montar la copia local del juego, o probar juntos, aunque no se nombre a Darío.
---

# Trabajo entre dos

**Hay un solo juego de verdad: `main` en GitHub.** Siempre funciona, y lo que se publica sale siempre de ahí.
Cada uno trabaja en **su copia** (un borrador) y los cambios llegan a `main` por PR.

## Ramas y PR
1. **Un bloque, una rama corta:** `bloque/<nombre>` desde `main` al día (`git pull` en main antes). Dura de unas
   horas a pocos días. El dueño del bloque va en `Estado.md`; **nunca trabajéis los dos en el mismo bloque.**
2. **Commits** con mensaje en español que diga qué se hizo (y qué trozo del mapa cambió, si cambió).
3. **Antes de fusionar, trae lo nuevo de `main` a la rama** (`git fetch` y `git merge origin/main`) y resuelve los
   choques. Si un choque toca una **decisión del juego** (números, qué hace algo), pregunta a Álvaro; si es mecánico
   (imports, orden), resuélvelo tú. Después `comprobar` otra vez.
4. **PR** (`gh pr create`) y espera a la CI. **Solo se fusiona con la CI en verde** (`gh pr merge --squash
   --delete-branch`). GitHub gratis no deja exigirlo en repos privados, así que **lo hace el freno del plugin**:
   niega `gh pr merge` si la CI no está en verde.
5. **Lo fusiona el dueño del bloque**, sin esperar revisión. Excepción: si el PR toca **lo compartido**
   (`src/shared/Data/`, `CLAUDE.md`, `.claude/`) y no es de Álvaro, hace falta su aprobación en el PR (el freno lo
   comprueba; sería lo de CODEOWNERS, que en privado gratis tampoco funciona).
6. **Nunca push directo a `main`** (el freno pregunta). Solo el primer push de un repo nuevo.

## Cada uno su copia (sin Team Create)
- Por qué no Team Create: estaríais en el **mismo sitio online** y, con ramas distintas y Rojo conectado, cada uno
  metería su código ahí y ganaría el último que guardó. Git solo junta el trabajo si cada uno trabaja aparte.
- **Montar la copia:** después de `git pull`, `lune run <kit>/kit/montar.luau` (o `--rehacer`) crea `<Nombre>.rbxl`
  con todo (código, mapa, ambiente). Ábrelo en Studio y conecta `rojo serve`: Studio enseña **tu rama**.
- Los cambios del otro llegan cuando fusiona en `main` y tú haces `pull` (y rehaces la copia si cambió el mapa,
  **guardando antes** lo tuyo con `guardar-mapa`).
- **Probar juntos:** cada uno sube su versión a «Pruebas» con `probar-nube` y entráis los dos.

## Trozos del mapa
Son binarios: git no puede juntar dos cambios del mismo trozo. **Un trozo, una persona a la vez**: apúntalo en
`Estado.md` («Trozos del mapa ocupados») al empezar y quítalo al guardarlo con `guardar-mapa` y hacer commit. Si
el trozo que necesitas está ocupado, avisa y espera o elige otro bloque.

## Publicar y fallos
- **Publicar: solo Álvaro, solo desde `main`, a mano** (skill `jefa`, lista de lanzamiento).
- Los fallos que encuentren los que prueban van como **issues** del repo del juego; Claude los convierte en bloques.

## Al montar un repo de juego nuevo (skill `juego-nuevo`)
- Repo **privado** en `AlvaroCepa/`, Darío como colaborador si Álvaro lo dice.
- La CI corre en cada push. El freno del plugin hace de protección de rama (verde para fusionar, aprobación de
  Álvaro para lo compartido, preguntar antes de push a main).
