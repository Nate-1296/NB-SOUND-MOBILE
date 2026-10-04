package com.nbsound.nb_sound_mobile.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.view.KeyEvent

class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            WidgetHelper.ACTION_PLAY_PAUSE -> {
                WidgetHelper.forwardMediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            }
            WidgetHelper.ACTION_NEXT -> {
                WidgetHelper.forwardMediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            }
            WidgetHelper.ACTION_PREV -> {
                WidgetHelper.forwardMediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            }
        }
    }
}
