package com.haylou.watch

import android.app.Notification
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Sees notifications only after the user grants "Notification access".
 * Anything not from an allow-listed app (or a call, if call alerts are on)
 * is dropped right here: its text is never read, stored or sent anywhere.
 */
class AlertListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val n = sbn.notification ?: return
        if (sbn.packageName == packageName) return
        val isCall = n.category == Notification.CATEGORY_CALL
        if (isCall) {
            if (!Bridge.callAlerts) return
        } else {
            if (sbn.packageName !in Bridge.allowedApps) return
            if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
            if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return
        }
        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
        Bridge.sendNotification(
            mapOf(
                "key" to sbn.key,
                "package" to sbn.packageName,
                "title" to title,
                "text" to text,
                "isCall" to isCall,
                "callActive" to (isCall && isOngoingCall(n)),
                "removed" to false,
            ),
        )
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        val n = sbn.notification ?: return
        if (n.category != Notification.CATEGORY_CALL || !Bridge.callAlerts) return
        Bridge.sendNotification(
            mapOf(
                "key" to sbn.key, "package" to sbn.packageName, "title" to "", "text" to "",
                "isCall" to true, "callActive" to false, "removed" to true,
            ),
        )
    }

    /** Answered call: CallStyle "ongoing" or a running call timer. */
    private fun isOngoingCall(n: Notification): Boolean {
        val extras = n.extras
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            extras.getInt(Notification.EXTRA_CALL_TYPE, 0) == Notification.CallStyle.CALL_TYPE_ONGOING
        ) return true
        return extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER, false)
    }
}
