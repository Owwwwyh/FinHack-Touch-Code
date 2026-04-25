package com.tng.finhack

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tng.finhack.keystore.SigningKeyManager

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.tng.finhack/keystore"
    }

    private lateinit var keyManager: SigningKeyManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        keyManager = SigningKeyManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureKey" -> {
                        try {
                            val kid = keyManager.ensureKey()
                            result.success(kid)
                        } catch (e: Exception) {
                            result.error("KEYSTORE_ERROR", e.message, null)
                        }
                    }
                    "sign" -> {
                        try {
                            val data = call.argument<ByteArray>("data") ?: ByteArray(0)
                            val signature = keyManager.sign(data)
                            result.success(signature)
                        } catch (e: Exception) {
                            result.error("SIGN_ERROR", e.message, null)
                        }
                    }
                    "getPublicKey" -> {
                        try {
                            val pub = keyManager.getPublicKey()
                            result.success(pub)
                        } catch (e: Exception) {
                            result.error("PUBKEY_ERROR", e.message, null)
                        }
                    }
                    "getAttestationChain" -> {
                        try {
                            val chain = keyManager.getAttestationChain()
                            // Flatten to single byte array for simplicity
                            val flattened = chain.reduce { acc, bytes -> acc + bytes }
                            result.success(flattened)
                        } catch (e: Exception) {
                            result.error("ATTEST_ERROR", e.message, null)
                        }
                    }
                    "hasKey" -> {
                        result.success(keyManager.hasKey())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
