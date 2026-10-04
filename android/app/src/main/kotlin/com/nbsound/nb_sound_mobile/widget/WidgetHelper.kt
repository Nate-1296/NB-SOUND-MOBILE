package com.nbsound.nb_sound_mobile.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.view.KeyEvent
import com.nbsound.nb_sound_mobile.MainActivity
import java.io.File

object WidgetHelper {
    const val PREFS_NAME = "nb_sound_widget_prefs"
    const val KEY_TITLE = "title"
    const val KEY_ARTIST = "artist"
    const val KEY_ALBUM = "album"
    const val KEY_IS_PLAYING = "is_playing"
    const val KEY_ART_URI = "art_uri"

    const val ACTION_PLAY_PAUSE = "com.nbsound.widget.ACTION_PLAY_PAUSE"
    const val ACTION_NEXT = "com.nbsound.widget.ACTION_NEXT"
    const val ACTION_PREV = "com.nbsound.widget.ACTION_PREV"

    fun saveTrackState(
        context: Context,
        title: String,
        artist: String,
        album: String,
        isPlaying: Boolean,
        artUri: String?
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_TITLE, title)
            .putString(KEY_ARTIST, artist)
            .putString(KEY_ALBUM, album)
            .putBoolean(KEY_IS_PLAYING, isPlaying)
            .putString(KEY_ART_URI, artUri)
            .apply()

        updateAllWidgets(context)
    }

    fun getTrackState(context: Context): TrackState {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return TrackState(
            title = prefs.getString(KEY_TITLE, "NB Sound") ?: "NB Sound",
            artist = prefs.getString(KEY_ARTIST, "Sin reproducción activa") ?: "Sin reproducción activa",
            album = prefs.getString(KEY_ALBUM, "") ?: "",
            isPlaying = prefs.getBoolean(KEY_IS_PLAYING, false),
            artUri = prefs.getString(KEY_ART_URI, null)
        )
    }

    fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)

        val compactIds = manager.getAppWidgetIds(ComponentName(context, CompactPlayerWidget::class.java))
        if (compactIds.isNotEmpty()) {
            CompactPlayerWidget.updateWidgets(context, manager, compactIds)
        }

        val cardIds = manager.getAppWidgetIds(ComponentName(context, CardPlayerWidget::class.java))
        if (cardIds.isNotEmpty()) {
            CardPlayerWidget.updateWidgets(context, manager, cardIds)
        }

        val quickIds = manager.getAppWidgetIds(ComponentName(context, QuickActionsWidget::class.java))
        if (quickIds.isNotEmpty()) {
            QuickActionsWidget.updateWidgets(context, manager, quickIds)
        }
    }

    fun getPendingIntentForAction(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java).apply {
            this.action = action
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    fun getPendingIntentForActivity(context: Context, route: String? = null, requestCode: Int = 100): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (!route.isNullOrEmpty()) {
                putExtra("route", route)
            }
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }

    fun loadArtworkBitmap(artUriString: String?, maxDim: Int): Bitmap? {
        if (artUriString.isNullOrEmpty()) return null
        return try {
            val uri = Uri.parse(artUriString)
            val path = uri.path ?: return null
            val file = File(path)
            if (!file.exists()) return null

            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.absolutePath, options)
            var sampleSize = 1
            while (options.outWidth / (sampleSize * 2) >= maxDim && options.outHeight / (sampleSize * 2) >= maxDim) {
                sampleSize *= 2
            }
            val decodeOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize }
            BitmapFactory.decodeFile(file.absolutePath, decodeOptions)
        } catch (_: Exception) {
            null
        }
    }

    fun forwardMediaKey(context: Context, keyCode: Int) {
        val mediaReceiver = ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver")

        val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = mediaReceiver
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        context.sendBroadcast(downIntent)

        val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = mediaReceiver
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
        context.sendBroadcast(upIntent)
    }

    data class TrackState(
        val title: String,
        val artist: String,
        val album: String,
        val isPlaying: Boolean,
        val artUri: String?
    )
}
