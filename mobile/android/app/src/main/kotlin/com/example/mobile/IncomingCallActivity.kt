package com.example.mobile

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class IncomingCallActivity : FlutterActivity() {

    private val CHANNEL = "cn_call/incoming"

    private var callerName = "CN CALL"
    private var callerId = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        callerName =
            intent.getStringExtra("caller_name") ?: "CN CALL"

        callerId =
            intent.getStringExtra("caller_id") ?: ""
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        Handler(Looper.getMainLooper()).postDelayed({

            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL
            ).invokeMethod(
                "incomingCall",
                mapOf(
                    "caller_name" to callerName,
                    "caller_id" to callerId
                )
            )

        }, 1000)
    }
}
