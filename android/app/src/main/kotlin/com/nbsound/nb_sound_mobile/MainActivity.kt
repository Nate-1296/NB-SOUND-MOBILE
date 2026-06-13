package com.nbsound.nb_sound_mobile

import android.content.ComponentName
import android.content.ContentUris
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {

    private val channelName = "com.nbsound/app_icon"
    private val localMediaChannel = "com.nbsound/local_media"
    private val pkg = "com.nbsound.nb_sound_mobile"

    // Las consultas a MediaStore y la decodificación de carátulas pueden tardar
    // (miles de pistas); se hacen fuera del hilo de UI para no bloquear/ANR. La
    // respuesta del MethodChannel se entrega en el hilo principal.
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Cambio de ícono PENDIENTE de aplicar. Conmutar el activity-alias del
    // lanzador mientras la app está en primer plano cierra la app de golpe (al
    // deshabilitarse el alias por el que se lanzó la tarea), sin que el usuario
    // alcance a leer el aviso. Por eso se difiere a `onStop` (cuando el usuario
    // ya salió de la app): el ícono nuevo aparece al volver a abrir.
    private var pendingIconKey: String? = null
    // Alias realmente habilitado cuando empezó el lote de cambios; se conserva
    // (no se pisa con cada cambio) para deshabilitar el correcto al aplicar.
    private var pendingIconPrevious: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val key = call.argument<String>("key") ?: ""
                        val previous = call.argument<String>("previous") ?: ""
                        scheduleIcon(key, previous)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, localMediaChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scan" -> {
                        val minDurationMs =
                            (call.argument<Number>("minDurationMs"))?.toLong() ?: 30000L
                        ioExecutor.execute {
                            try {
                                val songs = scanLocalAudio(minDurationMs)
                                mainHandler.post { result.success(songs) }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("scan_error", e.message, null)
                                }
                            }
                        }
                    }
                    "artwork" -> {
                        val id = (call.argument<Number>("id"))?.toLong() ?: -1L
                        val size = (call.argument<Number>("size"))?.toInt() ?: 256
                        ioExecutor.execute {
                            val bytes = if (id > 0) loadArtwork(id, size) else null
                            mainHandler.post { result.success(bytes) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Consulta MediaStore por todo el audio marcado como música (`IS_MUSIC`) de
     * duración suficiente ([minDurationMs], 30 s por defecto): así se queda solo
     * con música e ignora notas de voz/sonidos de apps (WhatsApp, etc.), tonos y
     * notificaciones (que MediaStore marca con `IS_MUSIC=0`). No pide carpeta:
     * usa el índice del sistema. Devuelve una lista de mapas con la metadata.
     */
    private fun scanLocalAudio(minDurationMs: Long): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ARTIST_ID,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.DATE_ADDED,
        )
        val selection =
            "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND " +
                "${MediaStore.Audio.Media.DURATION} >= ?"
        val args = arrayOf(minDurationMs.toString())
        contentResolver.query(
            collection,
            projection,
            selection,
            args,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
        )?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val artistIdCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST_ID)
            val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durationCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val trackCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
            val yearCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
            val mimeCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
            val dateCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val uri = ContentUris.withAppendedId(collection, id).toString()
                // TRACK puede venir como disco*1000+pista (p. ej. 1003 = disco 1, pista 3).
                val rawTrack = if (c.isNull(trackCol)) null else c.getInt(trackCol)
                val track = rawTrack?.let { if (it > 1000) it % 1000 else it }
                val artistName = if (c.isNull(artistCol)) null else c.getString(artistCol)
                val albumName = if (c.isNull(albumCol)) null else c.getString(albumCol)
                out.add(
                    mapOf(
                        "id" to id,
                        "uri" to uri,
                        "title" to (c.getString(titleCol) ?: "Desconocido"),
                        "artist" to normalizeUnknown(artistName),
                        "artistId" to (if (c.isNull(artistIdCol)) null else c.getLong(artistIdCol)),
                        "album" to normalizeUnknown(albumName),
                        "albumId" to (if (c.isNull(albumIdCol)) null else c.getLong(albumIdCol)),
                        "durationMs" to (if (c.isNull(durationCol)) 0L else c.getLong(durationCol)),
                        "track" to track,
                        "year" to (if (c.isNull(yearCol)) null else c.getInt(yearCol)),
                        "mime" to (if (c.isNull(mimeCol)) null else c.getString(mimeCol)),
                        "dateAddedSec" to (if (c.isNull(dateCol)) null else c.getLong(dateCol)),
                    ),
                )
            }
        }
        return out
    }

    /** `<unknown>` de MediaStore o vacío ⇒ null (pista "flotante", sin agrupar). */
    private fun normalizeUnknown(value: String?): String? {
        if (value == null) return null
        val v = value.trim()
        return if (v.isEmpty() || v == "<unknown>") null else v
    }

    /**
     * Carátula de una pista local por su id de MediaStore. En API 29+ usa
     * `loadThumbnail` (rápido, lo cachea el sistema); por debajo cae a la imagen
     * embebida vía [MediaMetadataRetriever]. Devuelve PNG en bytes, o null.
     */
    private fun loadArtwork(id: Long, size: Int): ByteArray? {
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }
        val uri: Uri = ContentUris.withAppendedId(collection, id)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val bmp = contentResolver.loadThumbnail(uri, Size(size, size), null)
                return bitmapToPng(bmp)
            }
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(this, uri)
                return retriever.embeddedPicture
            } finally {
                retriever.release()
            }
        } catch (_: Exception) {
            return null
        }
    }

    private fun bitmapToPng(bmp: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    /**
     * Programa el cambio de ícono al alias [key] (cadena vacía = AppIconDefault).
     * No toca el lanzador todavía: solo registra la intención. [previous] es el
     * alias activo según el lado Dart; se guarda únicamente la primera vez del
     * lote para deshabilitar en `onStop` el alias que de verdad estaba habilitado.
     */
    private fun scheduleIcon(key: String, previous: String) {
        if (pendingIconPrevious == null) {
            pendingIconPrevious = previous
        }
        pendingIconKey = key
    }

    override fun onStop() {
        applyPendingIcon()
        super.onStop()
    }

    /**
     * Aplica el cambio de ícono pendiente (si lo hay) habilitando el alias
     * elegido y deshabilitando el que estaba activo. Se ejecuta con la app en
     * segundo plano, así que si el sistema recicla la tarea es invisible para el
     * usuario; el ícono nuevo ya está al reabrir. DONT_KILL_APP evita matar el
     * proceso de forma inmediata.
     */
    private fun applyPendingIcon() {
        val key = pendingIconKey ?: return
        val previous = pendingIconPrevious ?: ""
        pendingIconKey = null
        pendingIconPrevious = null
        if (key == previous) return
        val pm = packageManager
        pm.setComponentEnabledSetting(
            componentFor(previous),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
        pm.setComponentEnabledSetting(
            componentFor(key),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    private fun componentFor(key: String): ComponentName {
        val name = if (key.isEmpty()) "$pkg.AppIconDefault" else "$pkg.AppIcon_$key"
        return ComponentName(pkg, name)
    }
}
