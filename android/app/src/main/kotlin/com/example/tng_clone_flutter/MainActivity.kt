package com.example.tng_clone_flutter

import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
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
        private const val PAYMENT_REQUESTS_CHANNEL = "com.tng.finhack/payment_requests"
        private const val INBOX_CHANNEL = "com.tng.finhack/inbox"

        @Volatile
        var paymentRequestEventSink: EventChannel.EventSink? = null

        @Volatile
        var inboxEventSink: EventChannel.EventSink? = null

        private val bufferedPaymentRequests = mutableListOf<Map<String, String>>()
        private val bufferedInboxEvents = mutableListOf<Map<String, String>>()

        @Synchronized
        fun publishPaymentRequestEvent(event: Map<String, String>) {
            val sink = paymentRequestEventSink
            if (sink != null) {
                sink.success(event)
            } else {
                bufferedPaymentRequests += event
            }
        }

        @Synchronized
        fun publishInboxEvent(event: Map<String, String>) {
            val sink = inboxEventSink
            if (sink != null) {
                sink.success(event)
            } else {
                bufferedInboxEvents += event
            }
        }

        @Synchronized
        private fun flushBufferedPaymentRequests() {
            val sink = paymentRequestEventSink ?: return
            if (bufferedPaymentRequests.isEmpty()) return
            val events = bufferedPaymentRequests.toList()
            bufferedPaymentRequests.clear()
            events.forEach(sink::success)
        }

        @Synchronized
        private fun flushBufferedInboxEvents() {
            val sink = inboxEventSink ?: return
            if (bufferedInboxEvents.isEmpty()) return
            val events = bufferedInboxEvents.toList()
            bufferedInboxEvents.clear()
            events.forEach(sink::success)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingNfcResult: MethodChannel.Result? = null
    private var activeIsoDep: IsoDep? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupKeystoreChannel(flutterEngine)
        setupNfcChannel(flutterEngine)
        setupPaymentRequestChannel(flutterEngine)
        setupInboxChannel(flutterEngine)
    }

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
                            val alias = call.argument<String>("alias")
                                ?: throw IllegalArgumentException("alias required")
                            val data = call.argument<ByteArray>("data")
                                ?: throw IllegalArgumentException("data required")
                            val amountCents = call.argument<Int>("amountCents") ?: 0
                            result.success(keyManager.sign(alias, data, amountCents))
                        }
                        "getPublicKey" -> {
                            val alias = call.argument<String>("alias")
                                ?: throw IllegalArgumentException("alias required")
                            result.success(keyManager.getPublicKey(alias))
                        }
                        "keyExists" -> {
                            val alias = call.argument<String>("alias")
                                ?: throw IllegalArgumentException("alias required")
                            result.success(keyManager.keyExists(alias))
                        }
                        "listKeys" -> result.success(keyManager.listKeys())
                        "deleteKey" -> {
                            val alias = call.argument<String>("alias")
                                ?: throw IllegalArgumentException("alias required")
                            keyManager.deleteKey(alias)
                            result.success(null)
                        }
                        "getAttestationCertificateChain" -> {
                            val alias = call.argument<String>("alias")
                                ?: throw IllegalArgumentException("alias required")
                            val chain = keyManager.getAttestationCertificateChain(alias)
                            result.success(
                                chain.map { Base64.encodeToString(it.encoded, Base64.NO_WRAP) },
                            )
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Keystore error [${call.method}]: ${e.message}", e)
                    result.error("KEYSTORE_ERROR", e.message, null)
                }
            }
    }

    private fun setupNfcChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NFC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendPaymentRequest" -> {
                        val requestJson = call.argument<String>("requestJson") ?: run {
                            result.error("NFC_ERROR", "requestJson argument missing", null)
                            return@setMethodCallHandler
                        }
                        sendPaymentRequest(requestJson, result)
                    }
                    "completePaymentTap" -> {
                        val jws = call.argument<String>("jws") ?: run {
                            result.error("NFC_ERROR", "jws argument missing", null)
                            return@setMethodCallHandler
                        }
                        val expectedReceiverPublicKey =
                            call.argument<ByteArray>("expectedReceiverPublicKey") ?: run {
                                result.error("NFC_ERROR", "expectedReceiverPublicKey missing", null)
                                return@setMethodCallHandler
                            }
                        completePaymentTap(jws, expectedReceiverPublicKey, result)
                    }
                    "stopReaderMode" -> {
                        stopReaderMode()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendPaymentRequest(requestJson: String, result: MethodChannel.Result) {
        val adapter = getAdapterOrError(result) ?: return
        pendingNfcResult = result

        adapter.enableReaderMode(
            this,
            { tag ->
                val isoDep = IsoDep.get(tag)
                if (isoDep == null) {
                    postError("NFC_ERROR", "Tag is not IsoDep")
                    return@enableReaderMode
                }
                activeIsoDep = isoDep
                Thread {
                    try {
                        isoDep.connect()
                        isoDep.timeout = 5000

                        val payerPublicKey = selectPublicKey(isoDep)
                        val requestBytes = requestJson.toByteArray(Charsets.UTF_8)
                        val chunks = requestBytes.toList()
                            .chunked(ApduHandler.CHUNK_SIZE) { it.toByteArray() }
                        val total = chunks.size

                        for ((index, chunk) in chunks.withIndex()) {
                            val response = isoDep.transceive(
                                ApduHandler.buildPutRequestApdu(index, total, chunk),
                            )
                            ensureSuccessStatus(response, "PUT-REQUEST chunk $index")
                        }

                        mainHandler.post {
                            pendingNfcResult?.success(payerPublicKey)
                            pendingNfcResult = null
                        }
                    } catch (e: Exception) {
                        postError("NFC_ERROR", e.message ?: "Unknown NFC error")
                    } finally {
                        cleanupReaderMode()
                    }
                }.start()
            },
            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            null,
        )
    }

    private fun completePaymentTap(
        jws: String,
        expectedReceiverPublicKey: ByteArray,
        result: MethodChannel.Result,
    ) {
        val adapter = getAdapterOrError(result) ?: return
        pendingNfcResult = result

        adapter.enableReaderMode(
            this,
            { tag: Tag ->
                val isoDep = IsoDep.get(tag)
                if (isoDep == null) {
                    postError("NFC_ERROR", "Tag is not IsoDep")
                    return@enableReaderMode
                }
                activeIsoDep = isoDep
                Thread {
                    try {
                        isoDep.connect()
                        isoDep.timeout = 5000

                        val receiverPublicKey = selectPublicKey(isoDep)
                        if (!receiverPublicKey.contentEquals(expectedReceiverPublicKey)) {
                            throw IllegalStateException("Receiver public key mismatch on tap 2")
                        }

                        val jwsBytes = jws.toByteArray(Charsets.UTF_8)
                        val chunks = jwsBytes.toList()
                            .chunked(ApduHandler.CHUNK_SIZE) { it.toByteArray() }
                        val total = chunks.size

                        for ((index, chunk) in chunks.withIndex()) {
                            val response = isoDep.transceive(
                                ApduHandler.buildPutDataApdu(index, total, chunk),
                            )
                            ensureSuccessStatus(response, "PUT-DATA chunk $index")
                        }

                        val ackResponse = isoDep.transceive(ApduHandler.buildGetAckApdu())
                        if (ackResponse.size < 66 ||
                            ackResponse[ackResponse.size - 2] != 0x90.toByte() ||
                            ackResponse.last() != 0x00.toByte()
                        ) {
                            throw IllegalStateException("Invalid GET-ACK response")
                        }

                        val ackSignature = ackResponse.copyOf(64)
                        mainHandler.post {
                            pendingNfcResult?.success(ackSignature)
                            pendingNfcResult = null
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Tap 2 failed: ${e.message}", e)
                        postError("NFC_ERROR", e.message ?: "Unknown NFC error")
                    } finally {
                        cleanupReaderMode()
                    }
                }.start()
            },
            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            null,
        )
    }

    private fun getAdapterOrError(result: MethodChannel.Result): NfcAdapter? {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        if (adapter == null) {
            result.error("NFC_NOT_AVAILABLE", "NFC adapter not found", null)
            return null
        }
        if (!adapter.isEnabled) {
            result.error("NFC_DISABLED", "NFC is disabled", null)
            return null
        }
        return adapter
    }

    private fun selectPublicKey(isoDep: IsoDep): ByteArray {
        val response = isoDep.transceive(ApduHandler.buildSelectApdu())
        if (response.size < 34 ||
            response[response.size - 2] != 0x90.toByte() ||
            response.last() != 0x00.toByte()
        ) {
            throw IllegalStateException("SELECT response invalid: ${response.size} bytes")
        }
        return response.copyOf(response.size - 2)
    }

    private fun ensureSuccessStatus(response: ByteArray, operation: String) {
        val sw1 = response.getOrElse(response.size - 2) { 0.toByte() }
        val sw2 = response.lastOrNull() ?: 0.toByte()
        if (sw1 != 0x90.toByte()) {
            throw IllegalStateException("$operation failed: SW=${"%02X%02X".format(sw1, sw2)}")
        }
    }

    private fun stopReaderMode() {
        NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this)
        cleanupReaderMode()
        pendingNfcResult?.error("NFC_CANCELLED", "Reader mode stopped", null)
        pendingNfcResult = null
    }

    private fun cleanupReaderMode() {
        runCatching { activeIsoDep?.close() }
        activeIsoDep = null
        NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this)
    }

    private fun postError(code: String, message: String) {
        mainHandler.post {
            pendingNfcResult?.error(code, message, null)
            pendingNfcResult = null
        }
    }

    private fun setupPaymentRequestChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PAYMENT_REQUESTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    paymentRequestEventSink = events
                    Log.d(TAG, "Payment request EventChannel: Flutter is listening")
                    flushBufferedPaymentRequests()
                }

                override fun onCancel(arguments: Any?) {
                    paymentRequestEventSink = null
                    Log.d(TAG, "Payment request EventChannel: Flutter cancelled")
                }
            })
    }

    private fun setupInboxChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, INBOX_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    inboxEventSink = events
                    Log.d(TAG, "Inbox EventChannel: Flutter is listening")
                    flushBufferedInboxEvents()
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
