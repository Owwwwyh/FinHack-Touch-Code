package com.example.tng_clone_flutter.hce

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import com.example.tng_clone_flutter.MainActivity
import com.example.tng_clone_flutter.keystore.SigningKeyManager

class TngHostApduService : HostApduService() {

    companion object {
        private const val TAG = "TngHostApduService"
        private const val KEY_ALIAS = "tng_signing_v1"
    }

    private enum class State {
        IDLE,
        SELECTED,
        RECEIVING_REQUEST,
        RECEIVING_TOKEN,
        READY_FOR_ACK,
    }

    private var state = State.IDLE
    private val chunkBuffer = mutableMapOf<Int, ByteArray>()
    private var expectedChunks = 0
    private var cachedAckSig: ByteArray? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val apdu = commandApdu ?: return ApduHandler.SW_ERROR

        return when {
            ApduHandler.isSelectAid(apdu) -> handleSelect()
            ApduHandler.isPutRequest(apdu) &&
                (state == State.SELECTED || state == State.RECEIVING_REQUEST) -> handlePutRequest(apdu)
            ApduHandler.isPutData(apdu) &&
                (state == State.SELECTED || state == State.RECEIVING_TOKEN) -> handlePutData(apdu)
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
            val publicKey = keyManager.getPublicKey(KEY_ALIAS)
            state = State.SELECTED
            ApduHandler.buildSelectResponse(publicKey)
        } catch (e: Exception) {
            Log.e(TAG, "SELECT failed: ${e.message}", e)
            ApduHandler.SW_ERROR
        }
    }

    private fun handlePutRequest(apdu: ByteArray): ByteArray {
        val idx = ApduHandler.getChunkIndex(apdu)
        val total = ApduHandler.getChunkTotal(apdu)
        val data = ApduHandler.getChunkData(apdu)

        if (state == State.SELECTED) {
            expectedChunks = total
            state = State.RECEIVING_REQUEST
        }

        chunkBuffer[idx] = data
        if (chunkBuffer.size < expectedChunks) {
            return ApduHandler.SW_OK
        }

        return try {
            val requestJson = assembleChunks()
            notifyPaymentRequest(requestJson)
            reset()
            ApduHandler.SW_OK
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process payment request: ${e.message}", e)
            reset()
            ApduHandler.SW_ERROR
        }
    }

    private fun handlePutData(apdu: ByteArray): ByteArray {
        val idx = ApduHandler.getChunkIndex(apdu)
        val total = ApduHandler.getChunkTotal(apdu)
        val data = ApduHandler.getChunkData(apdu)

        if (state == State.SELECTED) {
            expectedChunks = total
            state = State.RECEIVING_TOKEN
        }

        chunkBuffer[idx] = data
        if (chunkBuffer.size < expectedChunks) {
            return ApduHandler.SW_OK
        }

        return try {
            val allBytes = assembleChunks().toByteArray(Charsets.UTF_8)
            val jws = allBytes.toString(Charsets.UTF_8)

            val keyManager = SigningKeyManager.getInstance(this)
            cachedAckSig = keyManager.signSha256(KEY_ALIAS, allBytes)
            state = State.READY_FOR_ACK

            notifyReceivedToken(jws, cachedAckSig!!)
            ApduHandler.SW_LAST_CHUNK
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process JWS: ${e.message}", e)
            reset()
            ApduHandler.SW_ERROR
        }
    }

    private fun handleGetAck(): ByteArray {
        val ackSignature = cachedAckSig
        return if (ackSignature != null && ackSignature.size == 64) {
            val response = ApduHandler.buildAckResponse(ackSignature)
            reset()
            response
        } else {
            ApduHandler.SW_ERROR
        }
    }

    private fun notifyPaymentRequest(requestJson: String) {
        mainHandler.post {
            MainActivity.publishPaymentRequestEvent(mapOf("requestJson" to requestJson))
        }
    }

    private fun notifyReceivedToken(jws: String, ackSig: ByteArray) {
        mainHandler.post {
            MainActivity.publishInboxEvent(
                mapOf(
                    "jws" to jws,
                    "ackSig" to Base64.encodeToString(
                        ackSig,
                        Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
                    ),
                ),
            )
        }
    }

    override fun onDeactivated(reason: Int) {
        if (state != State.READY_FOR_ACK) {
            reset()
        }
    }

    private fun assembleChunks(): String {
        return (0 until expectedChunks)
            .flatMap { chunkBuffer[it]?.toList() ?: emptyList() }
            .toByteArray()
            .toString(Charsets.UTF_8)
    }

    private fun reset() {
        state = State.IDLE
        chunkBuffer.clear()
        expectedChunks = 0
        cachedAckSig = null
    }
}
