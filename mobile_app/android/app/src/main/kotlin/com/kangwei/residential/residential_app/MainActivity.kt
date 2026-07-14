package com.kangwei.residential.residential_app

import android.app.KeyguardManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "secure_residential/local_auth",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "authenticate" -> authenticate(
                    call.argument<String>("reason")
                        ?: "Verify your biometrics to continue.",
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun authenticate(reason: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            result.error(
                "unavailable",
                "Biometric login requires Android 9 or newer.",
                null,
            )
            return
        }

        val keyguard = getSystemService(KeyguardManager::class.java)
        if (keyguard?.isDeviceSecure != true) {
            result.error(
                "not_configured",
                "Set up a screen lock and biometric unlock on this device first.",
                null,
            )
            return
        }

        val executor = mainExecutor
        val cancellationSignal = CancellationSignal()
        var replied = false

        fun reply(block: () -> Unit) {
            if (replied) return
            replied = true
            block()
        }

        val prompt = BiometricPrompt.Builder(this)
            .setTitle("Biometric verification")
            .setSubtitle(reason)
            .setNegativeButton("Cancel", executor) { _, _ ->
                reply { result.success(false) }
            }
            .build()

        prompt.authenticate(
            cancellationSignal,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult,
                ) {
                    reply { result.success(true) }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    reply {
                        result.error(
                            flutterErrorCode(errorCode),
                            biometricErrorMessage(errorCode, errString.toString()),
                            errorCode,
                        )
                    }
                }

                override fun onAuthenticationFailed() {
                    // The prompt stays open after a failed scan.
                }
            },
        )
    }

    private fun flutterErrorCode(errorCode: Int): String {
        return when (errorCode) {
            1, 2, 3, 8, 12 -> "unavailable"
            11 -> "not_configured"
            5, 10, 13 -> "cancelled"
            else -> "unavailable"
        }
    }

    private fun biometricErrorMessage(errorCode: Int, platformMessage: String): String {
        val cleanMessage = platformMessage.trim()
        if (cleanMessage.isNotEmpty() && cleanMessage.lowercase() != "unknown") {
            return cleanMessage
        }

        return when (errorCode) {
            11 -> "Set up fingerprint or face unlock on this device first."
            1, 2, 3, 8, 12 -> "Biometric login is not available right now."
            5, 10, 13 -> "Biometric verification was cancelled."
            else -> "Biometric login is not available right now."
        }
    }
}
