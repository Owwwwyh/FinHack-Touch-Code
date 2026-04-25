package com.example.tng_clone_flutter.hce

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

class TngHostApduService : HostApduService() {
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        return ApduHandler.selectResponse
    }

    override fun onDeactivated(reason: Int) {
        // Phase 1 stub: nothing to clean up yet.
    }
}
