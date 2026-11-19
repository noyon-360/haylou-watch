package com.haylou.watch

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Starts ONE Flutter engine for the whole process and caches it, so the Dart
 * code (BLE link, notification forwarding) keeps running when the screen is
 * closed. The foreground service keeps the process alive.
 */
class WatchApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        Bridge.attach(this, engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "main"
    }
}
