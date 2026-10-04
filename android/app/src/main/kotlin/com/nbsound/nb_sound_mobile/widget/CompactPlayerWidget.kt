package com.nbsound.nb_sound_mobile.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.nbsound.nb_sound_mobile.R

class CompactPlayerWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        fun updateWidgets(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
            val state = WidgetHelper.getTrackState(context)
            val isIdle = state.title == "NB Sound" && (state.artist.isEmpty() || state.artist == "Sin reproducción activa")
            val displayTitle = if (isIdle) "NB Sound" else state.title
            val displayArtist = if (isIdle) "Toca para reproducir" else state.artist
            val coverBitmap = WidgetHelper.loadArtworkBitmap(state.artUri, 128)

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_compact_player)

                views.setTextViewText(R.id.widget_title, displayTitle)
                views.setTextViewText(R.id.widget_artist, displayArtist)

                if (coverBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_cover, coverBitmap)
                } else {
                    views.setImageViewResource(R.id.widget_cover, R.drawable.widget_cover_empty)
                }

                val playIcon = if (state.isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
                views.setImageViewResource(R.id.widget_btn_play, playIcon)

                // PendingIntents
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    WidgetHelper.getPendingIntentForActivity(context, null, 1)
                )

                val playIntent = if (isIdle) {
                    WidgetHelper.getPendingIntentForActivity(context, "/inicio", 2)
                } else {
                    WidgetHelper.getPendingIntentForAction(context, WidgetHelper.ACTION_PLAY_PAUSE, 2)
                }
                views.setOnClickPendingIntent(R.id.widget_btn_play, playIntent)

                views.setOnClickPendingIntent(
                    R.id.widget_btn_next,
                    WidgetHelper.getPendingIntentForAction(context, WidgetHelper.ACTION_NEXT, 3)
                )

                manager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
