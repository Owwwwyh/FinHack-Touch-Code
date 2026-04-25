package com.tng.finhack.keystore

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

/**
 * Manages Ed25519 signing key in Android Keystore.
 * Per docs/07-mobile-app.md §6 and docs/03-token-protocol.md §4.
 */
class SigningKeyManager(private val context: Context) {

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val ALIAS = "tng_signing_v1"
        private const val MIN_API_EDDSA = 33 // Ed25519 requires API 33+
    }

    private val keyStore: KeyStore by lazy {
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    /**
     * Ensure signing key exists; generate Ed25519 keypair if not.
     * Returns the key alias.
     */
    fun ensureKey(serverChallenge: ByteArray = "tng-finhack-attest".toByteArray()): String {
        if (keyStore.containsAlias(ALIAS)) return ALIAS

        if (Build.VERSION.SDK_INT < MIN_API_EDDSA) {
            throw UnsupportedOperationException(
                "Ed25519 requires API $MIN_API_EDDSA+. This device is API ${Build.VERSION.SDK_INT}."
            )
        }

        val spec = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("ed25519"))
            .setDigests(KeyProperties.DIGEST_NONE)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationValidityDurationSeconds(30)
            .apply {
                if (supportsStrongBox(context)) {
                    try {
                        setIsStrongBoxBacked(true)
                    } catch (e: StrongBoxUnavailableException) {
                        // Fall back to TEE
                    }
                }
            }
            .setAttestationChallenge(serverChallenge)
            .build()

        val gen = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            ANDROID_KEYSTORE
        )
        gen.initialize(spec)
        gen.generateKeyPair()

        return ALIAS
    }

    /**
     * Sign data with the Ed25519 private key.
     * Requires biometric/PIN unlock (setUserAuthenticationRequired).
     */
    fun sign(data: ByteArray): ByteArray {
        val key = keyStore.getKey(ALIAS, null) as PrivateKey
        return Signature.getInstance("Ed25519").run {
            initSign(key)
            update(data)
            sign()
        }
    }

    /**
     * Get the raw Ed25519 public key bytes (32 bytes).
     */
    fun getPublicKey(): ByteArray {
        val entry = keyStore.getEntry(ALIAS, null) as KeyStore.PrivateKeyEntry
        val pubKey = entry.certificate.publicKey
        // Ed25519 public key is the last 32 bytes of the X.509 encoded key
        val encoded = pubKey.encoded
        return encoded.copyOfRange(encoded.size - 32, encoded.size)
    }

    /**
     * Get the Android Key Attestation certificate chain.
     */
    fun getAttestationChain(): List<ByteArray> {
        val entry = keyStore.getEntry(ALIAS, null) as KeyStore.PrivateKeyEntry
        return entry.certificateChain.map { it.encoded }
    }

    /**
     * Check if a key with our alias already exists.
     */
    fun hasKey(): Boolean = keyStore.containsAlias(ALIAS)

    /**
     * Get the key ID (kid) — derived from the public key.
     */
    fun getKid(): String {
        val pub = getPublicKey()
        return pub.copyOfRange(0, 8).joinToString("") { "%02x".format(it) }
    }

    private fun supportsStrongBox(context: Context): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            context.packageManager.hasSystemFeature("android.hardware.strongbox_keystore")
    }
}
