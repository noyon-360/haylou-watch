package com.haylou.watch

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The one channel between Dart and our Kotlin code ("watch/native").
 * No third-party SDKs, no network access.
 */
object Bridge {
    private const val TAG = "WatchBridge"
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private lateinit var app: Context

    /** Packages whose notifications may be forwarded (set from Dart). */
    @Volatile var allowedApps: Set<String> = emptySet()
    @Volatile var callAlerts: Boolean = false

    private var ringtone: Ringtone? = null
    private val stopRing = Runnable { ring(false) }

    fun attach(context: Context, engine: FlutterEngine) {
        app = context.applicationContext
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, "watch/native")
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startService" -> {
                        startService(call.argument<String>("text") ?: "Connected")
                        result.success(null)
                    }
                    "stopService" -> {
                        app.stopService(Intent(app, WatchLinkService::class.java))
                        result.success(null)
                    }
                    "isListenerEnabled" -> result.success(isListenerEnabled())
                    "openListenerSettings" -> {
                        openListenerSettings()
                        result.success(null)
                    }
                    "setForwarding" -> {
                        allowedApps = (call.argument<List<String>>("apps") ?: emptyList()).toSet()
                        callAlerts = call.argument<Boolean>("calls") ?: false
                        result.success(null)
                    }
                    "launchableApps" -> result.success(launchableApps())
                    "ring" -> {
                        ring(call.argument<Boolean>("on") ?: false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native", e.message, null)
            }
        }
        channel = ch
    }

    /** Called by [AlertListenerService]; delivered on the main thread. */
    fun sendNotification(data: Map<String, Any>) {
        main.post { channel?.invokeMethod("notification", data) }
    }

    private fun startService(text: String) {
        val intent = Intent(app, WatchLinkService::class.java).putExtra("text", text)
        try {
            app.startForegroundService(intent)
        } catch (e: Exception) {
            // Android 12+ refuses to start it from the background; it will be
            // started next time the app is opened.
            Log.w(TAG, "Foreground service not started: ${e.message}")
        }
    }

    private fun isListenerEnabled(): Boolean {
        val enabled = Settings.Secure.getString(app.contentResolver, "enabled_notification_listeners") ?: return false
        val me = ComponentName(app, AlertListenerService::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
    }

    private fun openListenerSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                ComponentName(app, AlertListenerService::class.java).flattenToString(),
            )
        } else {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        }
        app.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /** Apps with a launcher icon (needs only a <queries> entry, not QUERY_ALL_PACKAGES). */
    private fun launchableApps(): List<Map<String, String>> {
        val pm = app.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo }
            .filter { it.packageName != app.packageName }
            .distinctBy { it.packageName }
            .map { mapOf("package" to it.packageName, "label" to it.loadLabel(pm).toString()) }
    }

    /** Find my phone: loud alarm sound for at most 30 s. */
    private fun ring(on: Boolean) {
        main.removeCallbacks(stopRing)
        ringtone?.stop()
        ringtone = null
        if (!on) return
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ringtone = RingtoneManager.getRingtone(app, uri)?.apply {
            audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            isLooping = true
            play()
        }
        main.postDelayed(stopRing, 30_000)
    }
}
