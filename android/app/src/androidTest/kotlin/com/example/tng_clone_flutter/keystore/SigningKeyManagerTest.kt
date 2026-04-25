package com.example.tng_clone_flutter.keystore

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.security.KeyStore
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SigningKeyManagerTest {

    private lateinit var context: Context
    private lateinit var keyManager: SigningKeyManager
    private val testAlias = "test_key_${System.currentTimeMillis()}"
    private val attestationChallenge = "test_challenge_data".toByteArray()

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        keyManager = SigningKeyManager(context)
    }

    @After
    fun tearDown() {
        // Clean up test keys
        if (keyManager.keyExists(testAlias)) {
            keyManager.deleteKey(testAlias)
        }
    }

    @Test
    fun testGenerateKey_CreatesValidKeyPair() {
        val publicKey = keyManager.generateKeyPair(testAlias, attestationChallenge)

        // Verify public key is 32 bytes (Ed25519)
        assert(publicKey.size >= 32) { "Public key should be at least 32 bytes" }

        // Verify key exists
        assert(keyManager.keyExists(testAlias)) { "Key should exist after generation" }
    }

    @Test
    fun testSign_ProducesValidSignature() {
        // Generate key first
        keyManager.generateKeyPair(testAlias, attestationChallenge)

        // Sign some data
        val dataToSign = "Hello, TNG!".toByteArray()
        val signature = keyManager.sign(testAlias, dataToSign)

        // Verify signature is produced
        assert(signature.isNotEmpty()) { "Signature should not be empty" }

        // ECDSA signatures are typically 70-72 bytes; Ed25519 is 64 bytes
        assert(signature.size in 64..72) { "Signature size should be valid (got ${signature.size})" }
    }

    @Test
    fun testSign_DifferentDataProducesDifferentSignature() {
        keyManager.generateKeyPair(testAlias, attestationChallenge)

        val data1 = "Transaction 1".toByteArray()
        val data2 = "Transaction 2".toByteArray()

        val sig1 = keyManager.sign(testAlias, data1)
        val sig2 = keyManager.sign(testAlias, data2)

        // Two different signatures should not be identical
        assert(!sig1.contentEquals(sig2)) { "Different data should produce different signatures" }
    }

    @Test
    fun testGetPublicKey_ReturnsConsistentKey() {
        val pubKey1 = keyManager.generateKeyPair(testAlias, attestationChallenge)
        val pubKey2 = keyManager.getPublicKey(testAlias)

        assert(pubKey1.contentEquals(pubKey2)) { "Public key should be consistent" }
    }

    @Test
    fun testKeyExists_ReturnsCorrectValue() {
        assert(!keyManager.keyExists(testAlias)) { "Key should not exist initially" }

        keyManager.generateKeyPair(testAlias, attestationChallenge)
        assert(keyManager.keyExists(testAlias)) { "Key should exist after generation" }

        keyManager.deleteKey(testAlias)
        assert(!keyManager.keyExists(testAlias)) { "Key should not exist after deletion" }
    }

    @Test
    fun testListKeys_IncludesGeneratedKey() {
        val keysBefore = keyManager.listKeys()
        keyManager.generateKeyPair(testAlias, attestationChallenge)
        val keysAfter = keyManager.listKeys()

        assert(keysAfter.contains(testAlias)) { "Generated key should be in list" }
        assert(keysAfter.size > keysBefore.size) { "List should contain the new key" }
    }

    @Test
    fun testDeleteKey_RemovesKeyFromStore() {
        keyManager.generateKeyPair(testAlias, attestationChallenge)
        assert(keyManager.keyExists(testAlias)) { "Key should exist before deletion" }

        keyManager.deleteKey(testAlias)
        assert(!keyManager.keyExists(testAlias)) { "Key should not exist after deletion" }
    }

    @Test
    fun testSign_WithNonexistentKey_ThrowsException() {
        try {
            keyManager.sign("nonexistent_key", "data".toByteArray())
            assert(false) { "Should throw exception for nonexistent key" }
        } catch (e: RuntimeException) {
            assert(e.message?.contains("not found") == true) { "Error should mention key not found" }
        }
    }

    @Test
    fun testGetPublicKey_WithNonexistentKey_ThrowsException() {
        try {
            keyManager.getPublicKey("nonexistent_key")
            assert(false) { "Should throw exception for nonexistent key" }
        } catch (e: RuntimeException) {
            assert(e.message?.contains("not found") == true) { "Error should mention key not found" }
        }
    }

    @Test
    fun testMultipleKeys_CanCoexist() {
        val alias1 = "${testAlias}_1"
        val alias2 = "${testAlias}_2"

        try {
            val key1 = keyManager.generateKeyPair(alias1, attestationChallenge)
            val key2 = keyManager.generateKeyPair(alias2, attestationChallenge)

            // Both keys should exist
            assert(keyManager.keyExists(alias1)) { "First key should exist" }
            assert(keyManager.keyExists(alias2)) { "Second key should exist" }

            // Both should be retrievable
            assert(keyManager.getPublicKey(alias1).contentEquals(key1)) {
                "First key should be retrievable"
            }
            assert(keyManager.getPublicKey(alias2).contentEquals(key2)) {
                "Second key should be retrievable"
            }

            // Signing with each should work independently
            val data = "test data".toByteArray()
            val sig1 = keyManager.sign(alias1, data)
            val sig2 = keyManager.sign(alias2, data)

            assert(!sig1.contentEquals(sig2)) { "Different keys should produce different signatures" }
        } finally {
            if (keyManager.keyExists(alias1)) keyManager.deleteKey(alias1)
            if (keyManager.keyExists(alias2)) keyManager.deleteKey(alias2)
        }
    }

    @Test
    fun testGetAttestationCertificateChain_ReturnsValidChain() {
        keyManager.generateKeyPair(testAlias, attestationChallenge)

        try {
            val chain = keyManager.getAttestationCertificateChain(testAlias)
            assert(chain.isNotEmpty()) { "Certificate chain should not be empty" }
        } catch (e: Exception) {
            // Attestation might not be available on all devices
            // This is acceptable for test purposes
            println("Attestation not available: ${e.message}")
        }
    }
}
