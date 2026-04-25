package com.example.tng_clone_flutter.keystore

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Log
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature  // ✅ use Signature, not Cipher

class SigningKeyManager(private val context: Context) {

    companion object {
        private const val TAG = "SigningKeyManager"
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALGORITHM = KeyProperties.KEY_ALGORITHM_EC
        private const val SIGNATURE_ALGORITHM = "SHA256withECDSA"

        @Volatile
        private var instance: SigningKeyManager? = null

        fun getInstance(context: Context): SigningKeyManager {
            return instance ?: synchronized(this) {
                instance ?: SigningKeyManager(context).also { instance = it }
            }
        }
    }

    private val keyStore: KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply {
        load(null)
    }

    fun generateKeyPair(alias: String, attestationChallenge: ByteArray): ByteArray {
        try {
            if (keyStore.containsAlias(alias)) {
                keyStore.deleteEntry(alias)
                Log.d(TAG, "Deleted existing key: $alias")
            }

            val builder = KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setAttestationChallenge(attestationChallenge)

            try {
                builder.setUserAuthenticationRequired(true)
                builder.setUserAuthenticationValidityDurationSeconds(300)
                Log.d(TAG, "User authentication enabled")
            } catch (e: Exception) {
                Log.w(TAG, "User authentication not supported: ${e.message}")
            }

            try {
                builder.setIsStrongBoxBacked(true)
                Log.d(TAG, "StrongBox (hardware-backed) enabled")
            } catch (e: Exception) {
                Log.w(TAG, "StrongBox not available, using software keystore: ${e.message}")
            }

            val spec = builder.build()
            val keyPairGenerator = KeyPairGenerator.getInstance(KEY_ALGORITHM, KEYSTORE_PROVIDER)
            keyPairGenerator.initialize(spec)
            val keyPair = keyPairGenerator.generateKeyPair()

            Log.d(TAG, "Key pair generated successfully: $alias")

            val encodedPublicKey = keyPair.public.encoded

            return if (encodedPublicKey.size >= 32) {
                encodedPublicKey.takeLast(32).toByteArray()
            } else {
                encodedPublicKey
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error generating key pair: ${e.message}", e)
            throw RuntimeException("Failed to generate key pair", e)
        }
    }

    fun sign(alias: String, data: ByteArray): ByteArray {
        try {
            val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
                ?: throw IllegalArgumentException("Key not found: $alias")

            val signature = Signature.getInstance(SIGNATURE_ALGORITHM)
            signature.initSign(entry.privateKey)
            signature.update(data)
            val signatureBytes = signature.sign()

            Log.d(TAG, "Data signed successfully with key: $alias (sig length: ${signatureBytes.size})")  // ✅ Bug 2 fixed

            return signatureBytes

        } catch (e: Exception) {
            Log.e(TAG, "Error signing data: ${e.message}", e)
            throw RuntimeException("Failed to sign data", e)
        }
    }

    fun getPublicKey(alias: String): ByteArray {
        try {
            val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
                ?: throw IllegalArgumentException("Key not found: $alias")

            val encodedPublicKey = entry.certificate.publicKey.encoded

            return if (encodedPublicKey.size >= 32) {
                encodedPublicKey.takeLast(32).toByteArray()
            } else {
                encodedPublicKey
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error getting public key: ${e.message}", e)
            throw RuntimeException("Failed to get public key", e)
        }
    }

    fun keyExists(alias: String): Boolean = keyStore.containsAlias(alias)

    fun listKeys(): List<String> = keyStore.aliases().toList()

    fun deleteKey(alias: String) {
        try {
            keyStore.deleteEntry(alias)
            Log.d(TAG, "Key deleted: $alias")
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting key: ${e.message}", e)
            throw RuntimeException("Failed to delete key", e)
        }
    }

    fun getAttestationCertificateChain(alias: String): Array<java.security.cert.Certificate> {
        try {
            val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
                ?: throw IllegalArgumentException("Key not found: $alias")

            val chain = entry.certificateChain
            Log.d(TAG, "Retrieved attestation chain with ${chain.size} certificates")
            return chain

        } catch (e: Exception) {
            Log.e(TAG, "Error getting attestation chain: ${e.message}", e)
            throw RuntimeException("Failed to get attestation chain", e)
        }
    }
}