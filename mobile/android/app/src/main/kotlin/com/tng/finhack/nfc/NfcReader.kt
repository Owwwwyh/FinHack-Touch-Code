package com.tng.finhack.nfc

import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.content.Context
import android.util.Log
import com.tng.finhack.hce.ApduHandler

/**
 * NFC Reader mode helper for the sender side.
 * Uses IsoDep to communicate with the receiver's HCE service.
 */
class NfcReader(private val context: Context) {

    companion object {
        private const val TAG = "NfcReader"
    }

    private val apduHandler = ApduHandler()

    /**
     * Process an NFC tag discovered in reader mode.
     * Returns the receiver's public key.
     */
    fun processTag(tag: Tag): ByteArray? {
        val isoDep = IsoDep.get(tag) ?: run {
            Log.w(TAG, "Tag does not support IsoDep")
            return null
        }

        try {
            isoDep.connect()
            val receiverPub = apduHandler.selectAid(isoDep)
            Log.d(TAG, "Selected AID, got receiver pub (${receiverPub.size} bytes)")
            return receiverPub
        } catch (e: Exception) {
            Log.e(TAG, "Error communicating with tag", e)
            return null
        } finally {
            try {
                isoDep.close()
            } catch (_: Exception) {}
        }
    }

    /**
     * Send a JWS token to the receiver via NFC.
     * Returns the ack-signature bytes.
     */
    fun sendJws(tag: Tag, jws: String): ByteArray? {
        val isoDep = IsoDep.get(tag) ?: return null

        try {
            isoDep.connect()
            return apduHandler.sendJws(isoDep, jws)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending JWS", e)
            return null
        } finally {
            try {
                isoDep.close()
            } catch (_: Exception) {}
        }
    }
}
