package com.tng.finhack.keystore

// SigningKeyManager.kt
//
// Android Keystore Ed25519 key lifecycle management.
// - Generates key on first call (ensureKey)
// - Signs data with the private key (sign)
// - Exposes public key to Dart (getPublicKey)
//
// docs/07-mobile-app.md §6 / docs/03-token-protocol.md §4

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

class SigningKeyManager(private val context: Context) {

    companion object {
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val ALIAS             = "tng_signing_v1"
    }

    /**
     * Ensure the Ed25519 keypair exists.
     * If not present, generates one with hardware-backed storage if available.
     * Returns the alias (used as kid base).
     *
     * @param serverChallenge Base64 attestation challenge from server
     */
    fun ensureKey(serverChallenge: String): String {
        val ks = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        if (ks.containsAlias(ALIAS)) return ALIAS

        val specBuilder = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
            .setDigests(KeyProperties.DIGEST_NONE)
            .setUserAuthenticationRequired(false) // set true in prod for biometric
            .setAttestationChallenge(serverChallenge.toByteArray())

        // Ed25519 is supported on API 33+; fall back to EC P-256 on older devices.
        // docs/07-mobile-app.md §13 / docs/03-token-protocol.md note
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            specBuilder.setAlgorithmParameterSpec(ECGenParameterSpec("ed25519"))
        } else {
            specBuilder.setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
        }

        // Use StrongBox (secure element) if available
        if (supportsStrongBox()) {
            specBuilder.setIsStrongBoxBacked(true)
        }

        val kpg = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC, KEYSTORE_PROVIDER
        )
        kpg.initialize(specBuilder.build())
        kpg.generateKeyPair()

        return ALIAS
    }

    /**
     * Sign [data] with the Keystore private key.
     * Returns the raw 64-byte Ed25519 signature (or DER-encoded ECDSA on pre-33).
     */
    fun sign(data: ByteArray): ByteArray {
        val ks  = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        val key = ks.getKey(ALIAS, null) as PrivateKey

        val algorithm = if (android.os.Build.VERSION.SDK_INT >= 33) "Ed25519" else "SHA256withECDSA"
        return Signature.getInstance(algorithm).run {
            initSign(key)
            update(data)
            sign()
        }
    }

    /**
     * Returns the raw 32-byte Ed25519 public key (or SubjectPublicKeyInfo-encoded
     * EC key on pre-33 devices — Dart side should handle both).
     */
    fun getPublicKey(): ByteArray {
        val ks  = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        val pub = ks.getCertificate(ALIAS)?.publicKey
            ?: throw IllegalStateException("Key not found — call ensureKey first")
        // For Ed25519: encoded is the 44-byte SubjectPublicKeyInfo; extract raw 32B
        // For EC P-256: return full encoded form
        return if (android.os.Build.VERSION.SDK_INT >= 33) {
            // Ed25519 SubjectPublicKeyInfo = 12-byte prefix + 32-byte key
            val enc = pub.encoded
            if (enc.size >= 44) enc.copyOfRange(enc.size - 32, enc.size) else enc
        } else {
            pub.encoded
        }
    }

    /**
     * Returns the DER-encoded attestation certificate chain (PEM bundle).
     * Used during device registration (POST /v1/devices/register).
     */
    fun getAttestationChain(): ByteArray {
        val ks    = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        val chain = ks.getCertificateChain(ALIAS)
            ?: return ByteArray(0)
        // Concatenate all DER-encoded certs
        return chain.map { it.encoded }.fold(ByteArray(0)) { acc, c -> acc + c }
    }

    private fun supportsStrongBox(): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= 28) {
            context.packageManager.hasSystemFeature(
                android.content.pm.PackageManager.FEATURE_STRONGBOX_KEYSTORE
            )
        } else false
    }
}
