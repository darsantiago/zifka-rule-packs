---
name: ahorro-de-tokens
description: "Ahorra tokens en sesiones largas: genera un relevo para continuar en otra sesión y aplica reglas de higiene de contexto. Úsalo al decir 'relevo' o 'cierra sesión', o cuando la sesión sea larga."
---

# Ahorro de tokens

Cada turno reenvía todo el contexto acumulado, así que una sesión larga cuesta más por turno. Este skill tiene tres partes.

## 1. Relevo de sesión

Se activa cuando Darío dice "relevo", "cierra sesión" o "continúa en otra sesión", cuando un aviso del hook lo sugiere, o cuando tú notes que la sesión ya es larga (más de ~30 turnos, muchas salidas voluminosas o cambio de tema). Si es por heurística, propón el relevo en una línea y espera su aprobación; no lo hagas sin avisar.

Genera un archivo de texto plano en `.claude/relevo/AAAA-MM-DD-tema.txt` (no Markdown; es para que lo lea Claude, no Darío). Contenido, en este orden y solo lo esencial:

1. Objetivo de la tarea, en 1-2 líneas.
2. Decisiones tomadas y su porqué (incluye lo que Darío descartó).
3. Estado actual: hecho, en curso, pendiente.
4. Rutas de archivos, ramas, servidores y comandos que funcionaron.
5. Lo que se intentó y falló, para no repetirlo.
6. Restricciones y preferencias que aplican a esta tarea.
7. Siguiente paso exacto.

Reglas:
- Referencia, no copies: pon la ruta o el enlace, no el contenido del archivo.
- No pegues transcripciones ni salidas largas de comandos.
- No incluyas contraseñas, llaves ni tokens; indica dónde están guardados.
- Si el trabajo toca git, anota rama y último commit.

Al terminar, entrega a Darío una sola línea lista para pegar en la sesión nueva:
`Lee .claude/relevo/<archivo>.txt y continúa desde el siguiente paso.`

Antes de cerrar, verifica que el archivo existe y que cada ruta citada existe.

## 2. Higiene durante la sesión

- Lee archivos por rangos (offset/limit), no completos, salvo que haga falta todo.
- Filtra salidas largas con grep, head o tail; no vuelques logs enteros.
- No releas lo que ya está en el contexto.
- Delega a un subagente las búsquedas amplias o la exploración de muchos archivos; que devuelva solo la conclusión.
- Respuestas cortas: no recapitules lo ya dicho ni narres cada paso.
- Si cambia el tema por completo, sugiere sesión nueva (con relevo) en vez de arrastrar contexto.
- Los datos estables (servidores, rutas, convenciones) van en el CLAUDE.md del proyecto, no se re-explican en el chat.

## 3. Freno de costo

Antes de lanzar varios subagentes o rondas de revisión (por ejemplo el Gauntlet completo), pregúntate si el costo de equivocarse lo justifica. Si no, usa el nivel liviano o ninguno y dilo en una línea.

## Hook opcional (solo Claude Code)

Para que el aviso sea automático, Darío puede instalar un hook que cuenta turnos y avisa a los 30, 60 y 90. Es un ajuste de configuración, no parte de este skill; si lo pide, créalo.

`~/.claude/hooks/contar-turnos.py`:
```python
#!/usr/bin/env python3
import json, sys, os
d = json.load(sys.stdin)
f = f"/tmp/turnos_{d['session_id']}"
n = int(open(f).read()) + 1 if os.path.exists(f) else 1
open(f, "w").write(str(n))
if n in (30, 60, 90):
    print(f"Aviso de ahorro de tokens: llevas {n} turnos. Propón a Darío generar un relevo (skill ahorro-de-tokens).")
```

`~/.claude/settings.json`:
```json
{"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "python3 ~/.claude/hooks/contar-turnos.py"}]}]}}
```

Lo que imprime el hook entra como contexto en el siguiente turno.
