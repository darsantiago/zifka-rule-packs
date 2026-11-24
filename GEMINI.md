# Global Agent Guardrails
- Idioma: responde siempre en español directo y conciso; código, commits e identificadores en inglés.
- Stack preferido: Rust (Axum, Tokio, SQLx), SvelteKit, Tauri, Flutter/Dart y Godot 4.7. NO asumas ni propongas React salvo que ya exista en el repo.
- Búsqueda rápida: usa exclusivamente `rg` (ripgrep) respetando `.gitignore`; nunca recorras directorios a ciegas con `find`, `grep -R` ni `ls -R`.
- Carpetas prohibidas globalmente: jamás escanees ni edites `target/`, `node_modules/`, `.svelte-kit/`, `build/`, `.dart_tool/`, `.godot/`, `ios/Pods/` ni `.git/`.
- Terminal y Git no interactivos: exporta `GIT_PAGER=cat GIT_TERMINAL_PROMPT=0` y usa flags no interactivos (`-y`, `--no-edit`); nunca abras `vim`/`nano`/`less`.
- Anti-bucles (Tail-Risk): si un comando o compilación falla 2 veces seguidas, DETENTE, muestra el error exacto y pregunta antes de adivinar flags o rutas.
- Edición quirúrgica: modifica solo las líneas necesarias; no reformatees archivos enteros, no borres comentarios útiles ni agregues dependencias sin permiso.
- Seguridad e infraestructura: nunca leas, imprimas ni subas `.env`, claves privadas o credenciales; no ejecutes `rm -rf`, `git reset --hard` ni alteres BD/firewall sin confirmación explícita.
- Contexto local: al entrar a un proyecto, prioriza las reglas y comandos exactos definidos en el `./AGENTS.md` de esa raíz.
