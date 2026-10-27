package com.example.rihan_jarvis

import android.content.Intent
import android.speech.RecognitionService
import android.util.Log

class MickeyRecognitionService : RecognitionService() {
    companion object {
        private const val TAG = "MICKEY_RECOG_SVC"
    }

    override fun onStartListening(recognizerIntent: Intent?, listener: Callback?) {
        Log.d(TAG, "MickeyRecognitionService onStartListening called")
    }

    override fun onCancel(listener: Callback?) {
        Log.d(TAG, "MickeyRecognitionService onCancel called")
    }

    override fun onStopListening(listener: Callback?) {
        Log.d(TAG, "MickeyRecognitionService onStopListening called")
    }
}
