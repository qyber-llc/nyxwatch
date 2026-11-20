package com.nyxwatch.android

import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.speech.tts.TextToSpeech
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import kotlin.concurrent.thread
import kotlin.math.sqrt

/**
 * NyxWatch Android Sentinel Service
 * - Detects physical pickup/motion via Accelerometer when armed
 * - Locks device immediately via DevicePolicyManager.lockNow()
 * - Speaks Flag alert via TextToSpeech (FR/EN)
 * - Exfiltrates alert + GPS to Mac Studio / Telegram
 */
class NyxWatchService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var lastTriggerTime = 0L
    private var armed = false
    private var flagMode = false
    private var macStudioUrl: String? = null
    private var tts: TextToSpeech? = null

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.US
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        armed = intent?.getBooleanExtra("armed", true) ?: true
        flagMode = intent?.getBooleanExtra("flagMode", false) ?: false
        macStudioUrl = intent?.getStringExtra("macStudioUrl")

        val accel = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        accel?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        return START_STICKY
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!armed) return
        val mag = sqrt(
            event.values[0] * event.values[0] +
            event.values[1] * event.values[1] +
            event.values[2] * event.values[2]
        )
        val now = System.currentTimeMillis()
        if (mag > 2.2f && now - lastTriggerTime > 30_000L) {
            lastTriggerTime = now
            onTamperDetected("Physical pickup / motion detected")
        }
    }

    private fun onTamperDetected(reason: String) {
        if (flagMode) {
            tts?.speak(
                "You are not authorized to touch this device. Alert transmitted.",
                TextToSpeech.QUEUE_FLUSH,
                null,
                "nyxwatch_flag"
            )
        }

        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        try {
            dpm.lockNow()
        } catch (_: SecurityException) {
            // Requires Device Admin enabled by user
        }

        macStudioUrl?.let { endpoint ->
            thread {
                runCatching {
                    val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Content-Type", "application/json")
                        doOutput = true
                    }
                    val body = JSONObject().apply {
                        put("app", "NyxWatch-Android")
                        put("reason", reason)
                        put("timestamp", System.currentTimeMillis())
                    }
                    conn.outputStream.use { it.write(body.toString().toByteArray()) }
                    conn.responseCode
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        tts?.shutdown()
        super.onDestroy()
    }
}
