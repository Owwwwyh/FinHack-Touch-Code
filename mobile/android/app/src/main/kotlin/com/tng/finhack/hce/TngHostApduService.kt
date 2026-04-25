package com.tng.finhack.hce

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import java.io.ByteArrayOutputStream

/**
 * HCE service for receiving offline NFC payments.
 * Implements the APDU exchange from docs/03-token-protocol.md §5.
 *
 * AID: F0544E47504159 (F0 + ASCII "TNGPAY")
 */
class TngHostApduService : HostApduService() {

    companion object {
        private const val TAG = "TngHCE"
        private const val AID = "F0544E47504159"
        private const val SW_OK = byteArrayOf(0x90.toByte(), 0x00)
        private const val SW_ERR = byteArrayOf(0x6A.toByte(), 0x80.toByte())
        private const val MAX_CHUNK_SIZE = 240
    }

    private val reassemblyBuffer = ByteArrayOutputStream()
    private var expectedChunks = 0
    private var receivedChunks = 0

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        val cla = commandApdu[0].toInt() and 0xFF
        val ins = commandApdu[1].toInt() and 0xFF

        return when {
            // SELECT AID
            cla == 0x00 && ins == 0xA4 -> handleSelectAid()
            // PUT-DATA chunk
            cla == 0x80 && ins == 0xD0 -> handlePutData(commandApdu)
            // GET ACK
            cla == 0x80 && ins == 0xC0 -> handleGetAck()
            else -> SW_ERR
        }
    }

    /**
     * SELECT AID: Return receiver's public key (32 bytes).
     */
    private fun handleSelectAid(): ByteArray {
        // TODO: Get actual Ed25519 public key from SigningKeyManager
        // For now, return a placeholder 32-byte key
        val receiverPub = ByteArray(32) { (it + 1).toByte() }
        return receiverPub + SW_OK
    }

    /**
     * PUT-DATA: Receive JWS chunks.
     * Format: 80 D0 <p1=chunk_index> <p2=total_chunks> <Lc> <data...>
     */
    private fun handlePutData(apdu: ByteArray): ByteArray {
        val p1 = apdu[2].toInt() and 0xFF  // chunk index
        val p2 = apdu[3].toInt() and 0xFF  // total chunks
        val lc = apdu[4].toInt() and 0xFF  // data length
        val data = apdu.copyOfRange(5, 5 + lc)

        expectedChunks = p2
        reassemblyBuffer.write(data)
        receivedChunks++

        return if (receivedChunks >= expectedChunks) {
            // Last chunk received
            val lastByte = 0x01.toByte()
            byteArrayOf(0x90.toByte(), lastByte)
        } else {
            SW_OK
        }
    }

    /**
     * GET ACK: Return ack-signature (sha256(jws) signed by receiver's key).
     * Command: 80 C0 00 00 40
     */
    private fun handleGetAck(): ByteArray {
        val jwsBytes = reassemblyBuffer.toByteArray()

        // TODO: Sign sha256(jws) with receiver's Ed25519 key via SigningKeyManager
        // For now, return a placeholder 64-byte signature
        val ackSig = ByteArray(64) { (it and 0xFF).toByte() }

        // Reset state
        reset()

        return ackSig + SW_OK
    }

    private fun reset() {
        reassemblyBuffer.reset()
        expectedChunks = 0
        receivedChunks = 0
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "HCE service deactivated, reason=$reason")
        reset()
    }
}
