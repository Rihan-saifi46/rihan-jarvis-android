package com.example.rihan_jarvis

import android.service.voice.VoiceInteractionService
import android.util.Log

class MickeyVoiceInteractionService : VoiceInteractionService() {
    companion object {
        const val TAG = "MICKEY_VIA_SERVICE"
    }

    override fun onReady() {
        super.onReady()
        Log.d(TAG, "MickeyVoiceInteractionService is ready and registered as system assistant")
    }

    override fun onShutdown() {
        Log.d(TAG, "MickeyVoiceInteractionService onShutdown")
        super.onShutdown()
    }
}
