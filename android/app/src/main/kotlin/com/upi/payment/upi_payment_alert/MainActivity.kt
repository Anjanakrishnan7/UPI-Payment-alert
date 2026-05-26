package com.upi.payment.upi_payment_alert

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.upi.payment.alert/notification_listener"
    private var channel: MethodChannel? = null
    
    private var pendingPaymentResult: MethodChannel.Result? = null
    private val UPI_PAY_REQUEST_CODE = 4321

    private val paymentReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent != null && intent.action == UPIPaymentNotificationListener.ACTION_PAYMENT) {
                val amount = intent.getDoubleExtra("amount", 0.0)
                val sender = intent.getStringExtra("sender") ?: "Unknown"
                val appName = intent.getStringExtra("appName") ?: "UPI App"
                val rawText = intent.getStringExtra("rawText") ?: ""

                val data = mapOf(
                    "amount" to amount,
                    "sender" to sender,
                    "appName" to appName,
                    "rawText" to rawText
                )
                
                channel?.invokeMethod("onPaymentNotification", data)
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isListenerPermissionGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openListenerSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "initiatePayment" -> {
                    pendingPaymentResult = result
                    val upiId = call.argument<String>("upiId")
                    val amount = call.argument<String>("amount")
                    val note = call.argument<String>("note")
                    val name = call.argument<String>("name") ?: "Recipient"
                    val appPackage = call.argument<String>("appPackage")

                    if (upiId == null || amount == null || note == null) {
                        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                        pendingPaymentResult = null
                        return@setMethodCallHandler
                    }

                    startUpiPayment(upiId, name, amount, note, appPackage)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startUpiPayment(upiId: String, name: String, amount: String, note: String, appPackage: String?) {
        val upiUri = Uri.Builder()
            .scheme("upi")
            .authority("pay")
            .appendQueryParameter("pa", upiId)
            .appendQueryParameter("pn", name)
            .appendQueryParameter("tn", note)
            .appendQueryParameter("am", amount)
            .appendQueryParameter("cu", "INR")
            .build()

        val intent = Intent(Intent.ACTION_VIEW)
        intent.data = upiUri

        if (appPackage != null && appPackage.isNotEmpty()) {
            intent.setPackage(appPackage)
            try {
                startActivityForResult(intent, UPI_PAY_REQUEST_CODE)
            } catch (e: Exception) {
                pendingPaymentResult?.error("APP_NOT_FOUND", "UPI application is not installed.", null)
                pendingPaymentResult = null
            }
        } else {
            val chooser = Intent.createChooser(intent, "Pay with UPI app")
            try {
                startActivityForResult(chooser, UPI_PAY_REQUEST_CODE)
            } catch (e: Exception) {
                pendingPaymentResult?.error("NO_UPI_APP", "No UPI apps found on this device.", null)
                pendingPaymentResult = null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == UPI_PAY_REQUEST_CODE) {
            if (pendingPaymentResult == null) return

            // If the user cancelled without choosing or backed out
            if (data == null) {
                pendingPaymentResult?.success("cancelled")
                pendingPaymentResult = null
                return
            }

            val response = data.getStringExtra("response")
            val dataUri = data.data?.toString()
            
            val rawResponse = response ?: dataUri ?: ""
            Log.d("UPIPayment", "Payment Response: $rawResponse")

            val status = parseUpiResponseStatus(rawResponse)
            pendingPaymentResult?.success(status)
            pendingPaymentResult = null
        }
    }

    private fun parseUpiResponseStatus(response: String): String {
        if (response.isEmpty()) {
            return "cancelled"
        }

        // Response format: txnId=...&responseCode=...&Status=SUCCESS&txnRef=...
        // Split and search for Status
        val keyValues = response.split("&")
        var status = "failure"
        var foundStatus = false

        for (kv in keyValues) {
            val parts = kv.split("=")
            if (parts.size >= 2) {
                val key = parts[0].trim().toLowerCase()
                val value = parts[1].trim().toLowerCase()
                if (key == "status") {
                    foundStatus = true
                    status = when (value) {
                        "success" -> "success"
                        "failure", "failed" -> "failure"
                        "submitted", "pending" -> "success" // submitted is treated as success to wait for confirmation
                        else -> "cancelled"
                    }
                    break
                }
            }
        }

        if (!foundStatus) {
            val lowerResponse = response.toLowerCase()
            return when {
                lowerResponse.contains("success") -> "success"
                lowerResponse.contains("fail") || lowerResponse.contains("error") -> "failure"
                else -> "cancelled"
            }
        }

        return status
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(UPIPaymentNotificationListener.ACTION_PAYMENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(paymentReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(paymentReceiver, filter)
        }
    }

    override fun onStop() {
        super.onStop()
        try {
            unregisterReceiver(paymentReceiver)
        } catch (e: Exception) {
            // Ignore if already unregistered
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val cn = android.content.ComponentName(this, UPIPaymentNotificationListener::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }
}
