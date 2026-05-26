package com.upi.payment.upi_payment_alert

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.regex.Pattern

class UPIPaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "UPINotificationListener"
        const val ACTION_PAYMENT = "com.upi.payment.alert.PAYMENT_NOTIFICATION"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName
        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""

        Log.d(TAG, "Notification received: App=$packageName, Title=$title, Text=$text")

        // Parse the payment details from title/text
        val paymentInfo = parsePaymentNotification(packageName, title, text)
        if (paymentInfo != null) {
            val (amount, sender) = paymentInfo
            Log.d(TAG, "Parsed Payment: Rs. $amount from $sender")

            // Broadcast to MainActivity
            val intent = Intent(ACTION_PAYMENT).apply {
                putExtra("amount", amount)
                putExtra("sender", sender)
                putExtra("appName", getAppName(packageName))
                putExtra("rawText", text)
            }
            sendBroadcast(intent)
        }
    }

    private fun parsePaymentNotification(packageName: String, title: String, text: String): Pair<Double, String>? {
        val combinedText = "$title $text"

        // Regex patterns to match UPI amounts (e.g., "Rs. 100", "Rs 100", "INR 150", "credited with Rs. 50")
        val amountPatterns = listOf(
            Pattern.compile("(?i)(?:rs\\.?|inr)\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("(?i)credited\\s+(?:with\\s+)?(?:rs\\.?|inr)?\\s*([\\d,]+(?:\\.\\d{2})?)"),
            Pattern.compile("(?i)received\\s+(?:rs\\.?|inr)?\\s*([\\d,]+(?:\\.\\d{2})?)")
        )

        var amount: Double? = null
        for (pattern in amountPatterns) {
            val matcher = pattern.matcher(combinedText)
            if (matcher.find()) {
                val amtStr = matcher.group(1)?.replace(",", "")
                amount = amtStr?.toDoubleOrNull()
                if (amount != null) break
            }
        }

        if (amount == null) return null

        // Try to identify sender/source
        var sender = "Someone"
        
        // Try to parse sender from text (e.g. "from John Doe", "by Sam", "sent by Alice")
        val senderPatterns = listOf(
            Pattern.compile("(?i)from\\s+([A-Za-z0-9\\s]{3,30})"),
            Pattern.compile("(?i)by\\s+([A-Za-z0-9\\s]{3,30})"),
            Pattern.compile("(?i)sent\\s+by\\s+([A-Za-z0-9\\s]{3,30})")
        )

        for (pattern in senderPatterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val match = matcher.group(1)?.trim()
                if (!match.isNullOrEmpty() && !match.contains("account", ignoreCase = true) && !match.contains("bank", ignoreCase = true)) {
                    sender = match
                    break
                }
            }
        }

        // Fallback: if sender wasn't parsed but title is a valid sender name
        if (sender == "Someone" && title.isNotEmpty() && 
            !title.contains("payment", ignoreCase = true) && 
            !title.contains("received", ignoreCase = true) &&
            !title.contains("alert", ignoreCase = true)) {
            sender = title
        }

        return Pair(amount, sender)
    }

    private fun getAppName(packageName: String): String {
        return when {
            packageName.contains("paisa.user") -> "Google Pay"
            packageName.contains("phonepe") -> "PhonePe"
            packageName.contains("paytm") -> "Paytm"
            packageName.contains("upiapp") -> "BHIM"
            packageName.contains("sms") || packageName.contains("messaging") -> "SMS Alert"
            else -> "UPI App"
        }
    }
}
