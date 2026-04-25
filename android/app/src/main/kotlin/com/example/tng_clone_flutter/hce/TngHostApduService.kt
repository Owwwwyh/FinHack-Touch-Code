package com.example.tng_clone_flutter.hce

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import com.example.tng_clone_flutter.MainActivity
import com.example.tng_clone_flutter.keystore.SigningKeyManager

/**
 * HCE service implementing the TNG offline payment receiver role.
 *
 * State machine:
 *   IDLE → (SELECT) → SELECTED → (PUT-DATA chunks) → RECEIVING → READY_FOR_ACK → (GET-ACK) → IDLE
 */
class TngHostApduService : HostApduService() {

    companion object {
        private const val TAG = "TngHostApduService"
        private const val KEY_ALIAS = "tng_signing_v1"
    }

    private enum class State { IDLE, SELECTED, RECEIVING, READY_FOR_ACK }

    private var state = State.IDLE
    private val chunkBuffer = mutableMapOf<Int, ByteArray>()
    private var expectedChunks = 0
    private var cachedAckSig: ByteArray? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val apdu = commandApdu ?: return ApduHandler.SW_ERROR

        return when {
            ApduHandler.isSelectAid(apdu) -> handleSelect()
            ApduHandler.isPutData(apdu) && (state == State.SELECTED || state == State.RECEIVING) -> handlePutData(apdu)
            ApduHandler.isGetAck(apdu) && state == State.READY_FOR_ACK -> handleGetAck()
            else -> {
                Log.w(TAG, "Unexpected APDU in state $state")
                ApduHandler.SW_ERROR
            }
        }
    }

    private fun handleSelect(): ByteArray {
        reset()
        return try {
            val keyManager = SigningKeyManager.getInstance(this)
            if (!keyManager.keyExists(KEY_ALIAS)) {
                Log.w(TAG, "No signing key found for alias $KEY_ALIAS")
                return ApduHandler.SW_NOT_FOUND
            }
            val pub = keyManager.getPublicKey(KEY_ALIAS)
            state = State.SELECTED
            Log.d(TAG, "SELECT handled; sending pub key (${pub.size}B)")
            ApduHandler.buildSelectResponse(pub)
        } catch (e: Exception) {
            Log.e(TAG, "SELECT failed: ${e.message}", e)
            ApduHandler.SW_ERROR
        }
    }

    private fun handlePutData(apdu: ByteArray): ByteArray {
        val idx = ApduHandler.getChunkIndex(apdu)
        val total = ApduHandler.getChunkTotal(apdu)
        val data = ApduHandler.getChunkData(apdu)

        if (state == State.SELECTED) {
            expectedChunks = total
            state = State.RECEIVING
        }

        chunkBuffer[idx] = data
        Log.d(TAG, "PUT-DATA chunk $idx/$total (${data.size}B)")

        if (chunkBuffer.size < expectedChunks) {
            return ApduHandler.SW_OK
        }

        return try {
            val allBytes = (0 until expectedChunks)
                .flatMap { chunkBuffer[it]?.toList() ?: emptyList() }
                .toByteArray()
            val jws = allBytes.toString(Charsets.UTF_8)
            Log.d(TAG, "JWS reassembled: ${jws.length} chars")

            val keyManager = SigningKeyManager.getInstance(this)
            cachedAckSig = keyManager.signSha256(KEY_ALIAS, allBytes)
            state = State.READY_FOR_ACK

            notifyFlutter(jws, cachedAckSig!!)
            ApduHandler.SW_LAST_CHUNK
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process received JWS: ${e.message}", e)
            reset()
            ApduHandler.SW_ERROR
        }
    }

    private fun handleGetAck(): ByteArray {
        val sig = cachedAckSig
        return if (sig != null && sig.size == 64) {
            Log.d(TAG, "GET-ACK: returning ack signature")
            val response = ApduHandler.buildAckResponse(sig)
            reset()
            response
        } else {
            Log.e(TAG, "GET-ACK: ack signature unavailable")
            ApduHandler.SW_ERROR
        }
    }

    private fun notifyFlutter(jws: String, ackSig: ByteArray) {
        mainHandler.post {
            val sink = MainActivity.inboxEventSink
            if (sink != null) {
                val event = mapOf(
                    "jws" to jws,
                    "ackSig" to Base64.encodeToString(
                        ackSig,
                        Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
                    ),
                )
                sink.success(event)
            } else {
                Log.w(TAG, "No Flutter inbox sink; token event dropped")
            }
        }
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "NFC deactivated: reason=$reason")
        if (state != State.READY_FOR_ACK) {
            reset()
        }
    }

    private fun reset() {
        state = State.IDLE
        chunkBuffer.clear()
        expectedChunks = 0
        cachedAckSig = null
    }
}
