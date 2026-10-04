package com.nbsound.nb_sound_mobile.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.nbsound.nb_sound_mobile.R

class QuickActionsWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        fun updateWidgets(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
            val state = WidgetHelper.getTrackState(context)

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_quick_actions)

                val playIcon = if (state.isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
                views.setImageViewResource(R.id.widget_action_play, playIcon)

                // PendingIntents
                views.setOnClickPendingIntent(
                    R.id.widget_action_play,
                    WidgetHelper.getPendingIntentForAction(context, WidgetHelper.ACTION_PLAY_PAUSE, 20)
                )
                views.setOnClickPendingIntent(
                    R.id.widget_action_fav,
                    WidgetHelper.getPendingIntentForActivity(context, "/favoritas", 21)
                )
                views.setOnClickPendingIntent(
                    R.id.widget_action_library,
                    WidgetHelper.getPendingIntentForActivity(context, "/biblioteca", 22)
                )
                views.setOnClickPendingIntent(
                    R.id.widget_action_sync,
                    WidgetHelper.getPendingIntentForActivity(context, "/sync", 23)
                )

                manager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
