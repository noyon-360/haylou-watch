package com.haylou.watch

import io.flutter.embedding.android.FlutterActivity

/** Shows the cached engine; closing the activity does not stop Dart. */
class MainActivity : FlutterActivity() {
    override fun getCachedEngineId(): String = WatchApp.ENGINE_ID
}
