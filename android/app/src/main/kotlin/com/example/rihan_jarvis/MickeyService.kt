package com.example.rihan_jarvis

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class MickeyService : Service() {

    companion object {
        const val TAG = "MICKEY_SERVICE"
        const val CHANNEL_ID = "mickey_voice_channel"
        const val NOTIFICATION_ID = 2026
        const val ACTION_STOP_MICKEY = "com.example.rihan_jarvis.ACTION_STOP_MICKEY"
        const val ACTION_START_MICKEY = "com.example.rihan_jarvis.ACTION_START_MICKEY"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "MickeyService onCreate")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "MickeyService onStartCommand action=${intent?.action}")

        if (intent?.action == ACTION_STOP_MICKEY) {
            Log.d(TAG, "Stop command received for MickeyService")
            stopForegroundService()
            return START_NOT_STICKY
        }

        startForegroundService()
        return START_STICKY
    }

    private fun startForegroundService() {
        val notification = buildNotification()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Android 14+ requires explicit FOREGROUND_SERVICE_TYPE_MICROPHONE
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            isRunning = true
            Log.d(TAG, "MickeyService successfully started in foreground")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service: ${e.message}", e)
            isRunning = false
        }
    }

    private fun stopForegroundService() {
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.d(TAG, "MickeyService stopped")
    }

    override fun onDestroy() {
        isRunning = false
        Log.d(TAG, "MickeyService onDestroy")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        // Intent to re-open the main Mickey app window
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action intent to stop listening directly from the notification
        val stopIntent = Intent(this, MickeyService::class.java).apply {
            action = ACTION_STOP_MICKEY
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Mickey is listening")
            .setContentText("Say \"Hey Mickey\" followed by your command")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop Listening", stopPendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Mickey Voice Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when Mickey is active and listening for your voice commands"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
