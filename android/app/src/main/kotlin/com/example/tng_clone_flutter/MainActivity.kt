package com.example.tng_clone_flutter

import android.os.Build
import android.util.Base64
import android.util.Log
import androidx.annotation.RequiresApi
import com.example.tng_clone_flutter.keystore.SigningKeyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.tng.finhack/keystore"
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val keyManager = SigningKeyManager.getInstance(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateKey" -> {
                    try {
                        val alias = call.argument<String>("alias")
                            ?: throw IllegalArgumentException("alias is required")
                        val attestationChallenge = call.argument<ByteArray>("attestationChallenge")
                            ?: ByteArray(0)

                        val publicKey = keyManager.generateKeyPair(alias, attestationChallenge)
                        result.success(publicKey)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in generateKey: ${e.message}", e)
                        result.error("KEYSTORE_ERROR", e.message, null)
                    }
                }

                "sign" -> {
                    try {
                        val alias = call.argument<String>("alias")
                            ?: throw IllegalArgumentException("alias is required")
                        val data = call.argument<ByteArray>("data")
                            ?: throw IllegalArgumentException("data is required")

                        val signature = keyManager.sign(alias, data)
                        result.success(signature)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in sign: ${e.message}", e)
                        result.error("KEYSTORE_ERROR", e.message, null)
                    }
                }

                "getPublicKey" -> {
                    try {
                        val alias = call.argument<String>("alias")
                            ?: throw IllegalArgumentException("alias is required")

                        val publicKey = keyManager.getPublicKey(alias)
                        result.success(publicKey)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in getPublicKey: ${e.message}", e)
                        result.error("KEYSTORE_ERROR", e.message, null)
                    }
                }

                "keyExists" -> {
                    try {
                        val alias = call.argument<String>("alias")
                            ?: throw IllegalArgumentException("alias is required")

                        val exists = keyManager.keyExists(alias)
                        result.success(exists)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in keyExists: ${e.message}", e)
                        result.error("KEYSTORE_ERROR", e.message, null)
                    }
                }

                "listKeys" -> {
                    try {
                        val keys = keyManager.listKeys()
                        result.success(keys)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in listKeys: ${e.message}", e)
                        result.error("KEYSTORE_ERROR", e.message, null)
                    }
                }

                "deleteKey" -> {
                    try {
                        val alias = call.argument<String>("alias")
                            ?: throw IllegalArgumentException("alias is required")

                        keyManager.deleteKey(alias)
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in deleteKey: ${e.message}", e)
                        result.error("KEYSTORE_ERROR", e.message, null)
                    }
                }

                "getAttestationCertificateChain" -> {
                    try {
                        val alias = call.argument<String>("alias")
                            ?: throw IllegalArgumentException("alias is required")

                        val certificateChain = keyManager.getAttestationCertificateChain(alias)
                        val encodedChain = certificateChain.map { cert ->
                            Base64.encodeToString(cert.encoded, Base64.NO_WRAP)
                        }
                        result.success(encodedChain)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in getAttestationCertificateChain: ${e.message}", e)
                        result.error("KEYSTORE_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
