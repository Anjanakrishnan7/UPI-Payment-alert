package com.upi.payment.upi_payment_alert

import android.app.Notification
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.regex.Pattern

import io.flutter.plugin.common.MethodChannel

class UPIPaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "UPINotificationListener"
        const val ACTION_PAYMENT = "com.upi.payment.alert.PAYMENT_NOTIFICATION"
        var methodChannel: MethodChannel? = null
        var originalVolume: Int? = null

        fun boostVolume(context: android.content.Context) {
            try {
                val audioManager = context.getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                if (originalVolume == null) {
                    originalVolume = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
                }
                val maxVolume = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, maxVolume, 0)
                Log.d(TAG, "Boosted stream music volume to max: $maxVolume, original: $originalVolume")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to boost volume: ${e.message}")
            }
        }

        fun restoreVolume(context: android.content.Context) {
            val vol = originalVolume
            if (vol != null) {
                try {
                    val audioManager = context.getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                    audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, vol, 0)
                    Log.d(TAG, "Restored stream music volume to: $vol")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to restore volume: ${e.message}")
                }
                originalVolume = null
            }
        }

        private val ALLOWED_PAYMENT_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user",
            "net.one97.paytm",
            "com.phonepe.app",
            "in.org.npci.upiapp"
        )

        private val SMS_PACKAGES = setOf(
            "com.google.android.apps.messaging",
            "com.android.mms",
            "com.samsung.android.messaging",
            "com.android.messaging",
            "com.google.android.sms"
        )
    }

    private fun isSmsSenderAllowed(title: String): Boolean {
        val upperTitle = title.uppercase().trim()
        val containsKeywords = listOf(
            "HDFCBK", "ICICIB", "SBIINB", "AXISBK", "KOTAKB",
            "YESBNK", "PNBSMS", "BOIIND", "CANBNK", "UNIONB"
        )
        for (keyword in containsKeywords) {
            if (upperTitle.contains(keyword)) {
                return true
            }
        }
        val pattern = Pattern.compile("^[A-Z]{2}-")
        return pattern.matcher(upperTitle).find()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val extras = sbn.notification.extras
        val titleTemp = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val textTemp = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
        Log.d(TAG, "onNotificationPosted: key=${sbn.key}, packageName=${sbn.packageName}, postTime=${sbn.postTime}, title=$titleTemp, text=$textTemp")

        val packageName = sbn.packageName
        val isPaymentApp = ALLOWED_PAYMENT_PACKAGES.contains(packageName)
        val isSmsApp = SMS_PACKAGES.contains(packageName)

        // Layer 1 - Source filter
        val passedLayer1 = isPaymentApp || isSmsApp
        if (!passedLayer1) {
            return
        }

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""

        if (title.isEmpty() || text.isEmpty()) {
            return
        }

        val passedSender = !isSmsApp || isSmsSenderAllowed(title)
        if (!passedSender) {
            return
        }

        // Layer 2 - Keyword filter
        val textLower = text.lowercase()
        val hasKeyword1 = textLower.contains("credited") ||
                          textLower.contains("debited") ||
                          textLower.contains("sent") ||
                          textLower.contains("received") ||
                          textLower.contains("paid") ||
                          textLower.contains("deducted") ||
                          textLower.contains("transferred") ||
                          textLower.contains("linked to vpa")

        val hasStandaloneNumber = Regex("""\d+(?:\.\d+)?\s*(?:was\s+)?(?:credited|debited)""").containsMatchIn(textLower)
        val hasKeyword2 = textLower.contains("rs.") ||
                          textLower.contains("rs ") ||
                          textLower.contains("inr") ||
                          textLower.contains("₹") ||
                          hasStandaloneNumber

        if (!hasKeyword1 || !hasKeyword2) {
            return
        }

        // Extract amount if present in raw text
        val amount = parseAnyAmount(text) ?: 0.0

        // Detect incoming (credited/received) vs outgoing (debited/sent/paid/transferred/deducted)
        val isIncoming = textLower.contains("credited") || textLower.contains("received")
        val isOutgoing = textLower.contains("debited") ||
                          textLower.contains("sent") ||
                          textLower.contains("paid") ||
                          textLower.contains("transferred") ||
                          textLower.contains("deducted") ||
                          textLower.contains("linked to vpa") ||
                          textLower.contains("paid to") ||
                          textLower.contains("transferred to") ||
                          textLower.contains("sent to")
        val isSent = if (isIncoming) false else if (isOutgoing) true else false

        val timestamp = sbn.postTime

        // Resolve friendly application name
        val friendlyAppName = getAppNameFriendly(packageName)

        val paymentData = HashMap<String, Any>()
        paymentData["packageName"] = packageName
        paymentData["title"] = title
        paymentData["body"] = text
        paymentData["timestamp"] = timestamp
        paymentData["amount"] = amount
        paymentData["sender"] = if (title.isNotEmpty()) title else friendlyAppName
        paymentData["appName"] = friendlyAppName
        paymentData["rawText"] = text
        paymentData["isSent"] = isSent
        paymentData["notificationKey"] = sbn.key

        android.os.Handler(android.os.Looper.getMainLooper()).post {
            boostVolume(this)
            methodChannel?.invokeMethod("onPaymentNotification", paymentData)
        }
    }

    private fun parseAnyAmount(text: String): Double? {
        val amountPatterns = listOf(
            Pattern.compile("(?i)(?:rs\\.?|inr|₹|rupees)\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("(?i)credited\\s+(?:with\\s+)?(?:rs\\.?|inr|₹)?\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("(?i)received\\s+(?:rs\\.?|inr|₹)?\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("(?i)sent\\s+(?:rs\\.?|inr|₹)?\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("(?i)paid\\s+(?:rs\\.?|inr|₹)?\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("(?i)transferred\\s+(?:rs\\.?|inr|₹)?\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("(?i)deducted\\s+(?:rs\\.?|inr|₹)?\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("([\\d,]+(?:\\.\\d{2})?)\\s*(?:rs\\.?|inr|₹|rupees)")
        )

        for (pattern in amountPatterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val amtStr = matcher.group(1)?.replace(",", "")
                val amt = amtStr?.toDoubleOrNull()
                if (amt != null) return amt
            }
        }
        return null
    }

    private fun getAppNameFriendly(packageName: String): String {
        return when (packageName) {
            "com.google.android.apps.nbu.paisa.user" -> "GPay"
            "net.one97.paytm" -> "Paytm"
            "com.phonepe.app" -> "PhonePe"
            "in.org.npci.upiapp" -> "BHIM"
            else -> {
                try {
                    val pm = packageManager
                    val info = pm.getApplicationInfo(packageName, 0)
                    pm.getApplicationLabel(info).toString()
                } catch (e: Exception) {
                    val parts = packageName.split(".")
                    if (parts.isNotEmpty()) {
                        parts.last().replaceFirstChar { it.uppercase() }
                    } else {
                        packageName
                    }
                }
            }
        }
    }
}
