package com.tng.finhack.hce

import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.util.Log
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * NFC Reader helper for the sender side.
 * Sends APDUs to the receiver's HCE service.
 */
class ApduHandler {

    companion object {
        private const val TAG = "ApduHandler"
        private const val AID = "F0544E47504159"
        private const val CHUNK_SIZE = 240
        private const val SELECT_AID_APDU = "00A4040007F0544E4750415900"
    }

    /**
     * SELECT AID on the peer device and retrieve receiver's public key.
     */
    suspend fun selectAid(isoDep: IsoDep): ByteArray {
        val response = transceive(isoDep, hexToBytes(SELECT_AID_APDU))
        val sw = (response[response.size - 2].toInt() and 0xFF shl 8) or
                 (response[response.size - 1].toInt() and 0xFF)

        if (sw != 0x9000) {
            throw RuntimeException("SELECT AID failed: SW=${sw.toString(16)}")
        }

        // Receiver pub key is everything before the status word
        return response.copyOfRange(0, response.size - 2)
    }

    /**
     * Send JWS in chunks.
     */
    suspend fun sendJws(isoDep: IsoDep, jws: String): ByteArray {
        val jwsBytes = jws.toByteArray(Charsets.UTF_8)
        val totalChunks = (jwsBytes.size + CHUNK_SIZE - 1) / CHUNK_SIZE

        for (i in 0 until totalChunks) {
            val start = i * CHUNK_SIZE
            val end = minOf(start + CHUNK_SIZE, jwsBytes.size)
            val chunk = jwsBytes.copyOfRange(start, end)

            val apdu = ByteArray(5 + chunk.size)
            apdu[0] = 0x80.toByte()  // CLA
            apdu[1] = 0xD0.toByte()  // INS = PUT-DATA
            apdu[2] = i.toByte()     // P1 = chunk index
            apdu[3] = totalChunks.toByte() // P2 = total chunks
            apdu[4] = chunk.size.toByte()  // Lc
            System.arraycopy(chunk, 0, apdu, 5, chunk.size)

            val response = transceive(isoDep, apdu)
            val sw = (response[response.size - 2].toInt() and 0xFF shl 8) or
                     (response[response.size - 1].toInt() and 0xFF)

            if (sw != 0x9000 && sw != 0x9001) {
                throw RuntimeException("PUT-DATA chunk $i failed: SW=${sw.toString(16)}")
            }
        }

        // GET ACK
        val ackApdu = hexToBytes("80C0000040")
        val ackResponse = transceive(isoDep, ackApdu)
        val ackSw = (ackResponse[ackResponse.size - 2].toInt() and 0xFF shl 8) or
                    (ackResponse[ackResponse.size - 1].toInt() and 0xFF)

        if (ackSw != 0x9000) {
            throw RuntimeException("GET ACK failed: SW=${ackSw.toString(16)}")
        }

        return ackResponse.copyOfRange(0, ackResponse.size - 2)
    }

    private suspend fun transceive(isoDep: IsoDep, apdu: ByteArray): ByteArray {
        return isoDep.transceive(apdu)
    }

    private fun hexToBytes(hex: String): ByteArray {
        val cleanHex = hex.replace(" ", "")
        return ByteArray(cleanHex.length / 2) { i ->
            Integer.parseInt(cleanHex.substring(i * 2, i * 2 + 2), 16).toByte()
        }
    }
}
