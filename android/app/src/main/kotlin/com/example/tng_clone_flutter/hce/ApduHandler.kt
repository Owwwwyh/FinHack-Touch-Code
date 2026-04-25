package com.example.tng_clone_flutter.hce

/**
 * APDU protocol constants and builders for the TNG offline payment NFC exchange.
 *
 * AID: F0544E47504159  (7 bytes: 0xF0 + ASCII "TNGPAY")
 *
 * Exchange sequence (Sender = reader, Receiver = HCE):
 *   SELECT AID          → receiver pub key (32B) + 9000
 *   PUT-DATA chunks     → 9000 (more) / 9001 (last chunk)
 *   GET-ACK             → ack signature (64B) + 9000
 */
object ApduHandler {

    /** Canonical AID — must match apduservice.xml */
    val AID: ByteArray = byteArrayOf(
        0xF0.toByte(), 0x54, 0x4E, 0x47, 0x50, 0x41, 0x59,
    )

    // Status words
    val SW_OK: ByteArray = byteArrayOf(0x90.toByte(), 0x00)
    val SW_LAST_CHUNK: ByteArray = byteArrayOf(0x90.toByte(), 0x01)
    val SW_ERROR: ByteArray = byteArrayOf(0x6A, 0x80.toByte())
    val SW_NOT_FOUND: ByteArray = byteArrayOf(0x6A, 0x82.toByte())

    // APDU instruction bytes
    private const val CLA_ISO: Byte = 0x00
    private const val INS_SELECT: Byte = 0xA4.toByte()
    private const val CLA_TNG: Byte = 0x80.toByte()
    private const val INS_PUT_DATA: Byte = 0xD0.toByte()
    private const val INS_GET_ACK: Byte = 0xC0.toByte()

    /** Max chunk payload in bytes (stay under typical 256-byte APDU limit). */
    const val CHUNK_SIZE = 240

    // ── APDU type detection ──────────────────────────────────────────────────

    fun isSelectAid(apdu: ByteArray): Boolean {
        if (apdu.size < 5) return false
        if (apdu[0] != CLA_ISO || apdu[1] != INS_SELECT) return false
        // P1=04 (by name), P2=00
        val lc = apdu[4].toInt() and 0xFF
        if (apdu.size < 5 + lc) return false
        val data = apdu.copyOfRange(5, 5 + lc)
        return data.contentEquals(AID)
    }

    fun isPutData(apdu: ByteArray): Boolean =
        apdu.size >= 5 && apdu[0] == CLA_TNG && apdu[1] == INS_PUT_DATA

    fun isGetAck(apdu: ByteArray): Boolean =
        apdu.size >= 4 && apdu[0] == CLA_TNG && apdu[1] == INS_GET_ACK

    /** P1 = chunk index (0-based). */
    fun getChunkIndex(apdu: ByteArray): Int = apdu[2].toInt() and 0xFF

    /** P2 = total number of chunks. */
    fun getChunkTotal(apdu: ByteArray): Int = apdu[3].toInt() and 0xFF

    /** Returns the data bytes of a PUT-DATA APDU (after the 5-byte header). */
    fun getChunkData(apdu: ByteArray): ByteArray {
        val lc = apdu[4].toInt() and 0xFF
        return apdu.copyOfRange(5, 5 + lc)
    }

    // ── APDU builders (sender / reader side) ────────────────────────────────

    /** Builds the SELECT AID command: 00 A4 04 00 07 <AID> 00 */
    fun buildSelectApdu(): ByteArray =
        byteArrayOf(CLA_ISO, INS_SELECT, 0x04, 0x00, AID.size.toByte()) + AID + byteArrayOf(0x00)

    /**
     * Builds a PUT-DATA command for one chunk.
     * 80 D0 <chunkIdx> <totalChunks> <Lc> <data>
     */
    fun buildPutDataApdu(chunkIdx: Int, totalChunks: Int, data: ByteArray): ByteArray {
        require(data.size <= CHUNK_SIZE) { "Chunk exceeds max size: ${data.size}" }
        return byteArrayOf(CLA_TNG, INS_PUT_DATA, chunkIdx.toByte(), totalChunks.toByte(), data.size.toByte()) + data
    }

    /** Builds the GET-ACK command: 80 C0 00 00 40 (Le=64 bytes expected) */
    fun buildGetAckApdu(): ByteArray =
        byteArrayOf(CLA_TNG, INS_GET_ACK, 0x00, 0x00, 0x40)

    // ── Response builders (receiver / HCE side) ──────────────────────────────

    /** Builds the SELECT response: <32B pub key> + 9000 */
    fun buildSelectResponse(publicKey32: ByteArray): ByteArray {
        require(publicKey32.size == 32) { "Public key must be 32 bytes" }
        return publicKey32 + SW_OK
    }

    /** Builds the ack response: <64B signature> + 9000 */
    fun buildAckResponse(signature64: ByteArray): ByteArray {
        require(signature64.size == 64) { "Ack signature must be 64 bytes" }
        return signature64 + SW_OK
    }
}

private operator fun ByteArray.plus(other: ByteArray): ByteArray {
    val result = ByteArray(size + other.size)
    copyInto(result)
    other.copyInto(result, size)
    return result
}
