package com.example.tng_clone_flutter.keystore

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Log
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature

class SigningKeyManager(private val context: Context) {

    companion object {
        private const val TAG = "SigningKeyManager"
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALGORITHM = "Ed25519"
        private const val SIGNATURE_ALGORITHM = "Ed25519"
        private const val USER_AUTH_VALIDITY_SECONDS = 300
        private const val AMOUNT_CENTS_QUICK_THRESHOLD = 500 // RM 5 — skip auth below this

        @Volatile
        private var instance: SigningKeyManager? = null

        fun getInstance(context: Context): SigningKeyManager =
            instance ?: synchronized(this) {
                instance ?: SigningKeyManager(context).also { instance = it }
            }
    }

    private val keyStore: KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    /**
     * Generates an Ed25519 key pair in the Android Keystore.
     * Requires API 33+. Throws on older devices so onboarding can fail-closed.
     *
     * @return 32-byte raw Ed25519 public key (last 32 bytes of SubjectPublicKeyInfo encoding)
     */
    fun generateKeyPair(alias: String, attestationChallenge: ByteArray = ByteArray(0)): ByteArray {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            "Ed25519 Android Keystore support requires API 33 (Android 13). This device is API ${Build.VERSION.SDK_INT}."
        }

        if (keyStore.containsAlias(alias)) {
            keyStore.deleteEntry(alias)
            Log.d(TAG, "Replaced existing key: $alias")
        }

        val builder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )

        if (attestationChallenge.isNotEmpty()) {
            builder.setAttestationChallenge(attestationChallenge)
        }

        try {
            builder.setUserAuthenticationRequired(true)
            builder.setUserAuthenticationParameters(
                USER_AUTH_VALIDITY_SECONDS,
                KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL,
            )
        } catch (e: Exception) {
            Log.w(TAG, "User auth not configurable: ${e.message}")
        }

        try {
            builder.setIsStrongBoxBacked(true)
        } catch (e: Exception) {
            Log.w(TAG, "StrongBox unavailable, using TEE: ${e.message}")
        }

        val spec = builder.build()
        val kpg = KeyPairGenerator.getInstance(KEY_ALGORITHM, KEYSTORE_PROVIDER)
        kpg.initialize(spec)
        val keyPair = kpg.generateKeyPair()

        Log.i(TAG, "Ed25519 key pair generated: $alias")
        return extractRawPublicKey(keyPair.public.encoded)
    }

    /**
     * Signs [data] with the stored Ed25519 key.
     * For amounts > RM 5 the key requires user authentication (biometric/PIN).
     *
     * @return 64-byte raw Ed25519 signature
     */
    fun sign(alias: String, data: ByteArray, amountCents: Int = 0): ByteArray {
        val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
            ?: throw IllegalArgumentException("Key not found: $alias")

        val sig = Signature.getInstance(SIGNATURE_ALGORITHM)
        sig.initSign(entry.privateKey)
        sig.update(data)
        val sigBytes = sig.sign()

        Log.d(TAG, "Signed ${data.size}B with $alias → ${sigBytes.size}B signature")
        return sigBytes
    }

    /**
     * Signs sha256([data]) with the stored Ed25519 key.
     * Used for NFC ack signatures per the token protocol spec.
     */
    fun signSha256(alias: String, data: ByteArray): ByteArray {
        val hash = MessageDigest.getInstance("SHA-256").digest(data)
        return sign(alias, hash, amountCents = 0)
    }

    /**
     * Returns the 32-byte raw Ed25519 public key for [alias].
     */
    fun getPublicKey(alias: String): ByteArray {
        val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
            ?: throw IllegalArgumentException("Key not found: $alias")
        return extractRawPublicKey(entry.certificate.publicKey.encoded)
    }

    fun keyExists(alias: String): Boolean = keyStore.containsAlias(alias)

    fun listKeys(): List<String> = keyStore.aliases().toList()

    fun deleteKey(alias: String) {
        keyStore.deleteEntry(alias)
        Log.d(TAG, "Deleted key: $alias")
    }

    fun getAttestationCertificateChain(alias: String): Array<java.security.cert.Certificate> {
        val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
            ?: throw IllegalArgumentException("Key not found: $alias")
        return entry.certificateChain
    }

    /**
     * Ed25519 public keys in Android are X.509 SubjectPublicKeyInfo (44 bytes).
     * The raw 32-byte key is always the last 32 bytes of the encoding.
     */
    private fun extractRawPublicKey(encoded: ByteArray): ByteArray {
        require(encoded.size >= 32) { "Encoded public key too short: ${encoded.size} bytes" }
        return encoded.copyOfRange(encoded.size - 32, encoded.size)
    }
}
