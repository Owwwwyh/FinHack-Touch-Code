package com.tng.finhack

// MainActivity.kt
//
// Hosts the Flutter engine and exposes the keystore MethodChannel bridge.
// docs/07-mobile-app.md §6 / lib/core/crypto/native_keystore.dart

import android.os.Bundle
import com.tng.finhack.keystore.SigningKeyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.tng.finhack/keystore"
    private lateinit var sigManager: SigningKeyManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sigManager = SigningKeyManager(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureKey" -> {
                        val challenge = call.argument<String>("serverChallenge") ?: ""
                        try {
                            val kid = sigManager.ensureKey(challenge)
                            result.success(kid)
                        } catch (e: Exception) {
                            result.error("KEYSTORE_ERROR", e.message, null)
                        }
                    }

                    "sign" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data == null) {
                            result.error("BAD_ARGS", "data required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val sig = sigManager.sign(data)
                            result.success(sig)
                        } catch (e: Exception) {
                            result.error("KEYSTORE_ERROR", e.message, null)
                        }
                    }

                    "getPublicKey" -> {
                        try {
                            val pub = sigManager.getPublicKey()
                            result.success(pub)
                        } catch (e: Exception) {
                            result.error("KEYSTORE_ERROR", e.message, null)
                        }
                    }

                    "getAttestationChain" -> {
                        try {
                            val chain = sigManager.getAttestationChain()
                            result.success(chain)
                        } catch (e: Exception) {
                            result.error("KEYSTORE_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
