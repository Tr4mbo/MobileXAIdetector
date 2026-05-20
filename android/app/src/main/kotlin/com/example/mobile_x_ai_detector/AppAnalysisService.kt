package com.example.mobile_x_ai_detector

import android.app.Service
import android.content.Intent
import android.os.IBinder

class AppAnalysisService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
