package com.nbsound.nb_sound_mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val channelName = "com.nbsound/app_icon"
    private val pkg = "com.nbsound.nb_sound_mobile"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val key = call.argument<String>("key") ?: ""
                        val previous = call.argument<String>("previous") ?: ""
                        setIcon(key, previous)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Conmuta el ícono del lanzador habilitando el alias [key] y deshabilitando el
     * anterior [previous]. Cadena vacía = alias por defecto (AppIconDefault). Solo
     * toca dos componentes (no la lista completa), así que el lado Dart pasa la
     * selección anterior. DONT_KILL_APP: no mata el proceso; el lanzador refresca
     * el ícono al volver a segundo plano o tras unos segundos.
     */
    private fun setIcon(key: String, previous: String) {
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
