package com.haylou.watch

import io.flutter.embedding.android.FlutterActivity

/** Shows the cached engine; closing the activity does not stop Dart. */
class MainActivity : FlutterActivity() {
    override fun getCachedEngineId(): String = WatchApp.ENGINE_ID

    override fun onStart() {
        super.onStart()
        Bridge.uiVisible = true
    }

    override fun onStop() {
        super.onStop()
        Bridge.uiVisible = false
        // A season change (manual pick or calendar) swaps the launcher icon
        // only once the app is in the background, so the open screen isn't closed.
        Bridge.applyPendingLauncher()
    }
}
