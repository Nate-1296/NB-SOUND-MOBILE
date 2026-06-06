# Control remoto — NB Sound Mobile

> **Contrato WS as-built (fuente de verdad): [`pc-contract.md` §5](pc-contract.md#5-websocket-apiv1control-control-remoto-spotify-connect).**
> El esquema exacto de estado plano, acciones (`tipo:"comando"`, `accion`) y el
> frame `cola` está ahí, tal como lo implementa el PC v1.1.0.

Cuando el celular y el PC están en la misma red y emparejados, la app puede
**controlar el reproductor del PC** y reflejar su estado en tiempo real
(estilo Spotify Connect). Canal: **WebSocket** (`/api/v1/control`).

> La superficie de control del lado PC se apoya en la API ya existente de
> `servicios/reproductor.py` (verificada en el repo de escritorio). El puente
> señal↔WS lo implementa el PC; este documento describe el **cliente móvil**.

**As-built:** implementado en `lib/features/remote_control/` (`RemoteController`,
`remote_dtos.dart`, `RemotePlayerView`) + unificación local/remoto en
`lib/features/player/application/playback.dart` (Bloque 5). Testeado contra un
servidor WebSocket local; **falta probar contra el PC real** — ver
[`app-state.md`](app-state.md).

## Modelo de interacción

- **Dos roles simultáneos**: el móvil puede reproducir **localmente** (su
  propio `just_audio`) o actuar como **mando** del reproductor del PC. La UI
  ofrece un selector de destino ("Este teléfono" / "Mi PC"), como Spotify
  Connect.
- **Bidireccional**: un cambio en el PC (desde su propia UI) se refleja en el
  móvil, y viceversa. La fuente de verdad del estado, en modo remoto, es el
  PC; el móvil renderiza lo que el PC publica.

## Protocolo sobre WebSocket

Mensajes JSON con `tipo` discriminado.

### Estado que publica el PC (push → móvil)

Derivado de las señales reales del reproductor del PC (`estadoCambiado`,
`pista_activaCambiada`, `progresoCambiado`, `colaCambiada`,
`volumenCambiado`, `modoCambiado`, `karaokeCambiado`):

```jsonc
{
  "tipo": "estado",
  "reproduciendo": true,
  "pista": { "id": 123, "titulo": "...", "artista": "...", "album": "...",
             "duracion_seg": 215, "cover_url": "..." },
  "posicion_seg": 42.3,
  "volumen": 80,
  "modo_repeticion": "ninguno|una|todas",
  "aleatorio": false,
  "karaoke_activo": false,
  "indice_cola": 4
}
```

### Comandos que envía el móvil (móvil → PC)

Mapean a métodos existentes del `Reproductor` del PC:

| Comando WS | Método PC (`servicios/reproductor.py`) |
| --- | --- |
| `play_pause` | `pausar_reanudar()` |
| `next` | `siguiente()` |
| `prev` | `anterior()` |
| `seek` `{posicion_seg}` | `buscar_posicion(posicion_seg)` |
| `set_volume` `{volumen}` | `set_volumen(volumen)` |
| `play_index` `{indice}` | `reproducir_indice_cola(indice)` |
| `repeat` `{modo}` | `set_modo_repeticion(modo)` |
| `shuffle` `{activo}` | `set_aleatorio(activo)` |
| `queue` (consulta) | `obtener_cola()` |

```jsonc
{ "tipo": "comando", "accion": "seek", "posicion_seg": 90.0 }
```

> Nota de implementación (lado PC): los comandos llegan en el hilo del
> servidor y deben **ejecutarse en el hilo de Qt** (las señales/objetos del
> reproductor no son thread-safe). Se marshalizan con
> `QMetaObject.invokeMethod`/señal. Detalle en el plan del escritorio,
> Tarea 3.4 de `../../nb_sound/docs/mobile-rollout-plan.md`.

## Cliente Flutter

- `web_socket_channel` para la conexión; reconexión automática con backoff si
  cae el WiFi.
- Un `RemoteController` (provider Riverpod) mantiene el último `estado`
  recibido y expone métodos que serializan comandos.
- La UI del reproductor es la **misma** que en modo local, pero su `provider`
  de origen cambia: local (`just_audio`) o remoto (`RemoteController`) según
  el destino elegido.
- **Optimismo controlado**: al enviar un comando, la UI puede anticipar el
  cambio, pero se corrige con el siguiente `estado` autoritativo del PC.

## Transición de destino

```text
local → remoto:  pausar local (opcional), suscribir WS, render estado del PC
remoto → local:  desuscribir WS, retomar reproducción local desde su estado
```

La cola del PC y la cola local son independientes; cambiar de destino no las
fusiona (decisión de v1: simplicidad y previsibilidad).

## Errores y degradación

- Sin WiFi / PC no alcanzable → el selector "Mi PC" se deshabilita; la app
  sigue en modo local.
- WS caído a mitad → reintento con backoff; mientras, la UI marca "reconectando".
- Comando no soportado por la versión del PC → ignorado con aviso (negociación
  por `version` del protocolo).
