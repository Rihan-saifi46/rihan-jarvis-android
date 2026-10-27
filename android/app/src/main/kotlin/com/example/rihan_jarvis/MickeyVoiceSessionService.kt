package com.example.rihan_jarvis

import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import android.util.Log

class MickeyVoiceSessionService : VoiceInteractionSessionService() {
    companion object {
        const val TAG = "MICKEY_SESSION_SVC"
    }

    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        Log.d(TAG, "MickeyVoiceSessionService onNewSession invoked")
        return MickeyVoiceSession(this)
    }
}
