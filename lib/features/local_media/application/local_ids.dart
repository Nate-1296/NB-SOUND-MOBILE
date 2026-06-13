/// Identidad de la **música local del teléfono** dentro del catálogo compartido.
///
/// La música local vive en las MISMAS tablas que el espejo del PC (para fluir
/// por toda la UI: biblioteca, buscar, playlists, cola, reproductor), pero con
/// **ids negativos** y `origen='local'`. El espejo del PC usa ids **positivos**;
/// el sync es delta + tombstones por ids del PC → **nunca toca** las filas
/// locales. El signo del id es además la guarda barata de aislamiento del
/// Connect: una pista local (`id < 0`) jamás se manda al PC.
library;

/// Origen de una fila del catálogo.
const String origenPc = 'pc';
const String origenLocal = 'local';

/// ¿La entidad (pista/álbum/artista) es música local del teléfono?
bool esIdLocal(int id) => id < 0;

/// Id local de una pista a partir del id de MediaStore (`_ID` del audio, > 0).
int idLocalPista(int mediaStoreId) => -(mediaStoreId.abs());

/// Id local de un álbum a partir del `ALBUM_ID` de MediaStore (> 0). Devuelve
/// null si MediaStore no aporta álbum (pista "flotante").
int? idLocalAlbum(int? mediaStoreAlbumId) =>
    (mediaStoreAlbumId == null || mediaStoreAlbumId <= 0)
        ? null
        : -mediaStoreAlbumId;

/// Id local de un artista a partir del `ARTIST_ID` de MediaStore (> 0). Devuelve
/// null si MediaStore no aporta artista (pista "flotante").
int? idLocalArtista(int? mediaStoreArtistId) =>
    (mediaStoreArtistId == null || mediaStoreArtistId <= 0)
        ? null
        : -mediaStoreArtistId;

/// Id de MediaStore (positivo) a partir de un id local negativo de pista.
int mediaStoreIdDePista(int idLocal) => idLocal.abs();

/// Esquema de `coverPath` para la carátula local (la resuelve `CoverResolver`
/// vía el canal nativo, por id de MediaStore de la pista). Se usa solo si la
/// pista tiene carátula embebida/álbum; si no, queda null y cae al placeholder.
String coverPathLocal(int mediaStoreId) => 'localart://$mediaStoreId';

/// Prefijo del [coverPathLocal].
const String esquemaCoverLocal = 'localart://';

/// Extrae el id de MediaStore de un [coverPathLocal]; null si no aplica.
int? mediaStoreIdDeCover(String? coverPath) {
  if (coverPath == null || !coverPath.startsWith(esquemaCoverLocal)) {
    return null;
  }
  return int.tryParse(coverPath.substring(esquemaCoverLocal.length));
}
