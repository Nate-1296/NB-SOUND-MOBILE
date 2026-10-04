package com.nbsound.nb_sound_mobile.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.nbsound.nb_sound_mobile.R

class CardPlayerWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        fun updateWidgets(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
            val state = WidgetHelper.getTrackState(context)
            val isIdle = state.title == "NB Sound" && (state.artist.isEmpty() || state.artist == "Sin reproducción activa")
            val displayTitle = if (isIdle) "NB Sound" else state.title
            val displayArtist = if (isIdle) "Tu biblioteca te espera" else state.artist
            val displayAlbum = if (isIdle) "Toca para abrir la música" else state.album
            val coverBitmap = WidgetHelper.loadArtworkBitmap(state.artUri, 256)

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_card_player)

                views.setTextViewText(R.id.widget_card_title, displayTitle)
                views.setTextViewText(R.id.widget_card_artist, displayArtist)

                if (displayAlbum.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_card_album, displayAlbum)
                    views.setViewVisibility(R.id.widget_card_album, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_card_album, View.GONE)
                }

                if (coverBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_card_cover, coverBitmap)
                } else {
                    views.setImageViewResource(R.id.widget_card_cover, R.drawable.widget_cover_empty)
                }

                val playIcon = if (state.isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
                views.setImageViewResource(R.id.widget_card_play, playIcon)

                // PendingIntents
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    WidgetHelper.getPendingIntentForActivity(context, null, 10)
                )
                views.setOnClickPendingIntent(
                    R.id.widget_card_prev,
                    WidgetHelper.getPendingIntentForAction(context, WidgetHelper.ACTION_PREV, 11)
                )

                val playIntent = if (isIdle) {
                    WidgetHelper.getPendingIntentForActivity(context, "/inicio", 12)
                } else {
                    WidgetHelper.getPendingIntentForAction(context, WidgetHelper.ACTION_PLAY_PAUSE, 12)
                }
                views.setOnClickPendingIntent(R.id.widget_card_play, playIntent)

                views.setOnClickPendingIntent(
                    R.id.widget_card_next,
                    WidgetHelper.getPendingIntentForAction(context, WidgetHelper.ACTION_NEXT, 13)
                )

                manager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
