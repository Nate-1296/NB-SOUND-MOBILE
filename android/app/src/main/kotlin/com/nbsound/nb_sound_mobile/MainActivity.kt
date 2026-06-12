package com.nbsound.nb_sound_mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val channelName = "com.nbsound/app_icon"
    private val pkg = "com.nbsound.nb_sound_mobile"

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
