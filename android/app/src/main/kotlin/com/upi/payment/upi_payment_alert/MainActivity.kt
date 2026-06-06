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

class MainActivity : FlutterActivity(), android.speech.RecognitionListener {
    private val CHANNEL = "com.upi.payment.alert/notification_listener"
    private var channel: MethodChannel? = null
    
    private var speechRecognizer: android.speech.SpeechRecognizer? = null
    private var speechIntent: Intent? = null
    private var isListeningForWakeWord = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val mChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = mChannel
        UPIPaymentNotificationListener.methodChannel = mChannel
        
        mChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isListenerPermissionGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openListenerSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "isBatteryOptimizationDisabled" -> {
                    result.success(isBatteryOptimizationDisabled())
                }
                "requestIgnoreBatteryOptimization" -> {
                    requestIgnoreBatteryOptimization()
                    result.success(null)
                }
                "boostVolume" -> {
                    UPIPaymentNotificationListener.boostVolume(this)
                    result.success(null)
                }
                "restoreVolume" -> {
                    UPIPaymentNotificationListener.restoreVolume(this)
                    result.success(null)
                }
                "startWakeWord" -> {
                    startWakeWordListening()
                    result.success(null)
                }
                "stopWakeWord" -> {
                    stopWakeWordListening()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startWakeWordListening() {
        if (isListeningForWakeWord) return
        
        if (android.content.pm.PackageManager.PERMISSION_GRANTED != androidx.core.content.ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO)) {
            androidx.core.app.ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.RECORD_AUDIO), 1)
            return
        }

        isListeningForWakeWord = true
        
        if (speechRecognizer == null) {
            speechRecognizer = android.speech.SpeechRecognizer.createSpeechRecognizer(this)
            speechRecognizer?.setRecognitionListener(this)
        }
        
        if (speechIntent == null) {
            speechIntent = Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL, android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                putExtra(android.speech.RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
        }
        
        // Use main thread for UI/Recognizer interactions
        runOnUiThread {
            speechRecognizer?.startListening(speechIntent)
        }
    }

    private fun stopWakeWordListening() {
        isListeningForWakeWord = false
        runOnUiThread {
            speechRecognizer?.stopListening()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1 && grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED) {
            startWakeWordListening()
        }
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        super.onDestroy()
    }

    // RecognitionListener implementation
    override fun onReadyForSpeech(params: android.os.Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {}
    
    override fun onError(error: Int) {
        if (isListeningForWakeWord) {
            // Restart listening continuously
            runOnUiThread {
                speechRecognizer?.startListening(speechIntent)
            }
        }
    }

    override fun onResults(results: android.os.Bundle?) {
        val matches = results?.getStringArrayList(android.speech.SpeechRecognizer.RESULTS_RECOGNITION)
        if (matches != null) {
            for (result in matches) {
                if (result.lowercase().contains("hey upi")) {
                    channel?.invokeMethod("onWakeWordDetected", null)
                    break
                }
            }
        }
        if (isListeningForWakeWord) {
            runOnUiThread {
                speechRecognizer?.startListening(speechIntent)
            }
        }
    }

    override fun onPartialResults(partialResults: android.os.Bundle?) {
        val matches = partialResults?.getStringArrayList(android.speech.SpeechRecognizer.RESULTS_RECOGNITION)
        if (matches != null) {
            for (result in matches) {
                if (result.lowercase().contains("hey upi")) {
                    channel?.invokeMethod("onWakeWordDetected", null)
                    // Reset to clear partial results
                    runOnUiThread {
                        speechRecognizer?.stopListening()
                        if (isListeningForWakeWord) {
                            speechRecognizer?.startListening(speechIntent)
                        }
                    }
                    break
                }
            }
        }
    }

    override fun onEvent(eventType: Int, params: android.os.Bundle?) {}

    private fun isNotificationServiceEnabled(): Boolean {
        val cn = android.content.ComponentName(this, UPIPaymentNotificationListener::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
    }

    private fun requestIgnoreBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to request battery optimization ignore", e)
            }
        }
    }
}
