package com.tng.finhack.hce

// TngHostApduService.kt
//
// Android HCE service. Acts as the RECEIVER side during NFC tap.
// Handles the APDU exchange protocol from docs/03-token-protocol.md §5.
//
// APDU state machine per session:
//   IDLE → KEY_EXCHANGE → RECEIVING → ACK_SENT → IDLE
//
// AID: F0 54 4E 47 50 41 59 ("F0TNGPAY")

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import com.tng.finhack.keystore.SigningKeyManager
import java.security.MessageDigest

class TngHostApduService : HostApduService() {

    companion object {
        private const val TAG = "TngHCE"

        // AID: F054 4E47 5041 59 (7 bytes)
        private val SELECT_AID = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(),
            0x07.toByte(),
            0xF0.toByte(), 0x54.toByte(), 0x4E.toByte(), 0x47.toByte(),
            0x50.toByte(), 0x41.toByte(), 0x59.toByte(),
            0x00.toByte()
        )

        private val STATUS_OK   = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val STATUS_LAST = byteArrayOf(0x90.toByte(), 0x01.toByte())
        private val STATUS_ERR  = byteArrayOf(0x6A.toByte(), 0x80.toByte())

        private const val INS_PUT_DATA = 0xD0.toByte()
        private const val INS_GET_ACK  = 0xC0.toByte()
    }

    // ── Session state ──────────────────────────────────────────────────────────

    private enum class SessionState { IDLE, KEY_EXCHANGE, RECEIVING, ACK_SENT }

    private var sessionState  = SessionState.IDLE
    private val jwsChunks     = mutableListOf<ByteArray>()
    private var totalChunks   = 0
    private var receivedJws   = ""
    private var ackSignature  = ByteArray(0)
    private lateinit var sigManager: SigningKeyManager

    override fun onCreate() {
        super.onCreate()
        sigManager = SigningKeyManager(applicationContext)
        sigManager.ensureKey("hce-session-challenge")
    }

    // ── APDU processing ────────────────────────────────────────────────────────

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        Log.d(TAG, "APDU: ${commandApdu.toHex()}")

        // ── SELECT AID ────────────────────────────────────────────────────────
        if (commandApdu.startsWith(byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00))) {
            return handleSelectAid()
        }

        val ins = commandApdu.getOrNull(1) ?: return STATUS_ERR

        return when (ins) {
            INS_PUT_DATA -> handlePutData(commandApdu)
            INS_GET_ACK  -> handleGetAck()
            else         -> STATUS_ERR
        }
    }

    private fun handleSelectAid(): ByteArray {
        // Reset session state
        sessionState = SessionState.KEY_EXCHANGE
        jwsChunks.clear()
        totalChunks  = 0
        receivedJws  = ""
        ackSignature = ByteArray(0)

        // Return receiver's 32-byte public key + STATUS_OK
        val pubKey = try {
            sigManager.getPublicKey()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get public key", e)
            return STATUS_ERR
        }

        Log.d(TAG, "SELECT AID → returning pub key (${pubKey.size}B)")
        return pubKey + STATUS_OK
    }

    private fun handlePutData(apdu: ByteArray): ByteArray {
        if (sessionState != SessionState.KEY_EXCHANGE && sessionState != SessionState.RECEIVING) {
            return STATUS_ERR
        }
        sessionState = SessionState.RECEIVING

        // C-APDU: 80 D0 <p1=chunk_index> <p2=total_chunks> <Lc> <data>
        if (apdu.size < 5) return STATUS_ERR

        val chunkIndex = apdu[2].toInt() and 0xFF
        val totalCount = apdu[3].toInt() and 0xFF
        val lc         = apdu[4].toInt() and 0xFF

        if (apdu.size < 5 + lc) return STATUS_ERR

        val chunk = apdu.copyOfRange(5, 5 + lc)
        totalChunks = totalCount

        // Store chunk at correct index position
        while (jwsChunks.size <= chunkIndex) jwsChunks.add(ByteArray(0))
        jwsChunks[chunkIndex] = chunk

        val isLast = (chunkIndex == totalCount - 1)

        if (isLast) {
            // Reassemble JWS
            receivedJws = jwsChunks.joinToString("") { String(it, Charsets.UTF_8) }
            Log.d(TAG, "JWS reassembled: ${receivedJws.take(40)}...")

            // Compute ack signature: sign sha256(jws) with our key
            ackSignature = computeAckSignature(receivedJws)
            sessionState = SessionState.ACK_SENT

            return STATUS_LAST  // 90 01 = last chunk received
        }

        return STATUS_OK
    }

    private fun handleGetAck(): ByteArray {
        if (sessionState != SessionState.ACK_SENT || ackSignature.isEmpty()) {
            return STATUS_ERR
        }
        // Return 64-byte ack signature + STATUS_OK
        return ackSignature + STATUS_OK
    }

    /**
     * Sign sha256(jws) with receiver's Ed25519 key.
     * This proves to the sender that "device with kid X received token at time Y".
     * docs/03-token-protocol.md §5.4
     */
    private fun computeAckSignature(jws: String): ByteArray {
        val sha256 = MessageDigest.getInstance("SHA-256")
        val digest = sha256.digest(jws.toByteArray(Charsets.UTF_8))
        return try {
            sigManager.sign(digest)
        } catch (e: Exception) {
            Log.e(TAG, "Ack signature failed", e)
            ByteArray(64) // zero-filled fallback (still stored, not required for settlement)
        }
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "HCE deactivated, reason=$reason — clearing session state")
        sessionState = SessionState.IDLE
        jwsChunks.clear()
        // Note: if deactivated before ACK_SENT, the received JWS is not committed.
        // The sender's outbox is only written after ack is received.
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private fun ByteArray.toHex() = joinToString("") { "%02X".format(it) }

    private fun ByteArray.startsWith(prefix: ByteArray): Boolean {
        if (this.size < prefix.size) return false
        return prefix.indices.all { this[it] == prefix[it] }
    }
}
