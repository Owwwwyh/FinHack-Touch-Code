package com.example.tng_clone_flutter

import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import com.example.tng_clone_flutter.hce.ApduHandler
import com.example.tng_clone_flutter.keystore.SigningKeyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val KEYSTORE_CHANNEL = "com.tng.finhack/keystore"
        private const val NFC_CHANNEL = "com.tng.finhack/nfc"
        private const val INBOX_CHANNEL = "com.tng.finhack/inbox"

        /** Written by EventChannel StreamHandler; read by TngHostApduService. */
        @Volatile
        var inboxEventSink: EventChannel.EventSink? = null
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingNfcResult: MethodChannel.Result? = null
    private var activeIsoDep: IsoDep? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupKeystoreChannel(flutterEngine)
        setupNfcChannel(flutterEngine)
        setupInboxChannel(flutterEngine)
    }

    // ── Keystore channel ──────────────────────────────────────────────────────

    private fun setupKeystoreChannel(flutterEngine: FlutterEngine) {
        val keyManager = SigningKeyManager.getInstance(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEYSTORE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "generateKey" -> {
                            val alias = call.argument<String>("alias") ?: "tng_signing_v1"
                            val challenge = call.argument<ByteArray>("attestationChallenge") ?: ByteArray(0)
                            result.success(keyManager.generateKeyPair(alias, challenge))
                        }
                        "sign" -> {
                            val alias = call.argument<String>("alias") ?: throw IllegalArgumentException("alias required")
                            val data = call.argument<ByteArray>("data") ?: throw IllegalArgumentException("data required")
                            val amountCents = call.argument<Int>("amountCents") ?: 0
                            result.success(keyManager.sign(alias, data, amountCents))
                        }
                        "getPublicKey" -> {
                            val alias = call.argument<String>("alias") ?: throw IllegalArgumentException("alias required")
                            result.success(keyManager.getPublicKey(alias))
                        }
                        "keyExists" -> {
                            val alias = call.argument<String>("alias") ?: throw IllegalArgumentException("alias required")
                            result.success(keyManager.keyExists(alias))
                        }
                        "listKeys" -> result.success(keyManager.listKeys())
                        "deleteKey" -> {
                            val alias = call.argument<String>("alias") ?: throw IllegalArgumentException("alias required")
                            keyManager.deleteKey(alias)
                            result.success(null)
                        }
                        "getAttestationCertificateChain" -> {
                            val alias = call.argument<String>("alias") ?: throw IllegalArgumentException("alias required")
                            val chain = keyManager.getAttestationCertificateChain(alias)
                            result.success(chain.map { Base64.encodeToString(it.encoded, Base64.NO_WRAP) })
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Keystore error [${call.method}]: ${e.message}", e)
                    result.error("KEYSTORE_ERROR", e.message, null)
                }
            }
    }

    // ── NFC reader-mode channel ───────────────────────────────────────────────

    private fun setupNfcChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NFC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "selectAndGetReceiverPub" -> selectAndGetReceiverPub(result)
                    "sendJwsAndGetAck" -> {
                        val jws = call.argument<String>("jws") ?: run {
                            result.error("NFC_ERROR", "jws argument missing", null)
                            return@setMethodCallHandler
                        }
                        sendJwsAndGetAck(jws, result)
                    }
                    "stopReaderMode" -> {
                        stopReaderMode()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun selectAndGetReceiverPub(result: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        if (adapter == null) {
            result.error("NFC_NOT_AVAILABLE", "NFC adapter not found", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("NFC_DISABLED", "NFC is disabled", null)
            return
        }

        pendingNfcResult = result

        adapter.enableReaderMode(
            this,
            { tag: Tag ->
                val isoDep = IsoDep.get(tag)
                if (isoDep == null) {
                    postError("NFC_ERROR", "Tag is not IsoDep")
                    return@enableReaderMode
                }
                try {
                    isoDep.connect()
                    isoDep.timeout = 5000

                    val selectApdu = ApduHandler.buildSelectApdu()
                    val response = isoDep.transceive(selectApdu)

                    // Expect: <32B pub key> 90 00
                    if (response.size >= 34 &&
                        response[response.size - 2] == 0x90.toByte() &&
                        response.last() == 0x00.toByte()
                    ) {
                        val receiverPub = response.copyOf(response.size - 2)
                        activeIsoDep = isoDep
                        mainHandler.post {
                            pendingNfcResult?.success(receiverPub)
                            pendingNfcResult = null
                        }
                    } else {
                        isoDep.close()
                        postError("NFC_ERROR", "SELECT response invalid: ${response.size}B")
                    }
                } catch (e: Exception) {
                    runCatching { isoDep.close() }
                    postError("NFC_ERROR", e.message ?: "Unknown error")
                }
            },
            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            null,
        )
    }

    private fun sendJwsAndGetAck(jws: String, result: MethodChannel.Result) {
        val isoDep = activeIsoDep
        if (isoDep == null || !isoDep.isConnected) {
            result.error("NFC_ERROR", "No active NFC connection; call selectAndGetReceiverPub first", null)
            return
        }

        Thread {
            try {
                val jwsBytes = jws.toByteArray(Charsets.UTF_8)
                val chunks = jwsBytes.toList().chunked(ApduHandler.CHUNK_SIZE) { it.toByteArray() }
                val total = chunks.size

                for ((idx, chunk) in chunks.withIndex()) {
                    val apdu = ApduHandler.buildPutDataApdu(idx, total, chunk)
                    val resp = isoDep.transceive(apdu)
                    val sw1 = resp.getOrElse(resp.size - 2) { 0.toByte() }
                    val sw2 = resp.lastOrNull() ?: 0.toByte()
                    if (sw1 != 0x90.toByte()) {
                        throw Exception("PUT-DATA chunk $idx failed: SW=${"%02X%02X".format(sw1, sw2)}")
                    }
                    Log.d(TAG, "Sent chunk $idx/$total")
                }

                val ackApdu = ApduHandler.buildGetAckApdu()
                val ackResp = isoDep.transceive(ackApdu)

                // Expect: <64B sig> 90 00
                if (ackResp.size >= 66 &&
                    ackResp[ackResp.size - 2] == 0x90.toByte() &&
                    ackResp.last() == 0x00.toByte()
                ) {
                    val ackSig = ackResp.copyOf(64)
                    mainHandler.post { result.success(ackSig) }
                } else {
                    throw Exception("GET-ACK response invalid: ${ackResp.size}B")
                }
            } catch (e: Exception) {
                Log.e(TAG, "NFC send failed: ${e.message}", e)
                mainHandler.post { result.error("NFC_ERROR", e.message, null) }
            } finally {
                runCatching { isoDep.close() }
                activeIsoDep = null
                NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this)
            }
        }.start()
    }

    private fun stopReaderMode() {
        NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this)
        runCatching { activeIsoDep?.close() }
        activeIsoDep = null
        pendingNfcResult?.error("NFC_CANCELLED", "Reader mode stopped", null)
        pendingNfcResult = null
    }

    private fun postError(code: String, message: String) {
        mainHandler.post {
            pendingNfcResult?.error(code, message, null)
            pendingNfcResult = null
        }
    }

    // ── Inbox EventChannel ────────────────────────────────────────────────────

    private fun setupInboxChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, INBOX_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    inboxEventSink = events
                    Log.d(TAG, "Inbox EventChannel: Flutter is listening")
                }

                override fun onCancel(arguments: Any?) {
                    inboxEventSink = null
                    Log.d(TAG, "Inbox EventChannel: Flutter cancelled")
                }
            })
    }

    override fun onDestroy() {
        super.onDestroy()
        stopReaderMode()
    }
}
