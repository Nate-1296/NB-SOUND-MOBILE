import '../../sync/application/conexion_provider.dart';

/// Decisión de descarga según el estado de conexión con el PC (estilo Spotify):
/// la media (audio/portadas/letra/karaoke) vive en el PC, así que descargar sin
/// un PC alcanzable o emparejado merece un aviso en vez de encolar en silencio.
///
/// - [sinEnlace]: no hay PC emparejado; nada descargará la cola. No se encola.
/// - [encolarAvisando]: hay PC pero no responde ahora; se encola (la cola
///   persiste y el mantenimiento la retoma al reconectar) y se avisa.
/// - [encolar]: PC conectado; se encola sin fricción.
enum DownloadGate { sinEnlace, encolarAvisando, encolar }

/// Mapea el estado de conexión a la decisión de descarga. Pura y testeable.
DownloadGate gateDescarga(ConexionEstado estado) => switch (estado) {
      ConexionEstado.sinEnlace => DownloadGate.sinEnlace,
      ConexionEstado.desconectado => DownloadGate.encolarAvisando,
      ConexionEstado.conectado => DownloadGate.encolar,
    };
