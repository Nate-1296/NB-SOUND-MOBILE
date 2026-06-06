# core/

Infraestructura transversal, sin dependencias de features:

- `config/` — constantes, flavors, endpoints base del protocolo de sync.
- `di/` — providers raíz de Riverpod (BD, dio, audio handler).
- `router/` — configuración de `go_router`.
- `error/` — tipos de error/Result compartidos.
- `utils/` — helpers puros (formato de duración, hashing, etc.).

Regla: `core/` no importa de `features/`. Las features importan de `core/`.
