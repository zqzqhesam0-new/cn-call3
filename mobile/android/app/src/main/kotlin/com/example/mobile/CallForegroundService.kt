package com.example.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

class CallForegroundService : Service() {

    private val CHANNEL_ID = "cn_call_incoming_call"

    override fun onCreate() {
        super.onCreate()

        createChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        val callerName =
            intent?.getStringExtra("caller_name")
                ?: "CN CALL"

        val callerId =
            intent?.getStringExtra("caller_id")
                ?: ""

        // لا نفتح FlutterActivity ثانية من الإشعار.
        // CallKitService هو المسؤول عن واجهة المكالمة الواردة.
        val notificationIntent = Intent(
            this,
            MainActivity::class.java
        ).apply {
            setFlags(
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            1001,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(
            this,
            CHANNEL_ID
        )
            .setContentTitle(callerName)
            .setContentText("مكالمة واردة")
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(
                pendingIntent,
                true
            )
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

        startForeground(
            1001,
            notification
        )

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createChannel() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Incoming Calls",
                NotificationManager.IMPORTANCE_HIGH
            )

            channel.description =
                "CN CALL incoming calls"

            val manager =
                getSystemService(
                    NotificationManager::class.java
                )

            manager.createNotificationChannel(channel)
        }
    }
}
