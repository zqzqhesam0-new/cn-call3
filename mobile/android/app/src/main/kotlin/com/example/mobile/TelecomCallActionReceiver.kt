package com.example.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

class TelecomCallActionReceiver : BroadcastReceiver() {

    companion object {
        private const val ENGINE_ID = "cn_call_telecom_background_engine"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return

        val action = when (intent.action) {
            CallConnectionService.ACTION_CALL_ACCEPT -> "accept"
            CallConnectionService.ACTION_CALL_REJECT -> "reject"
            CallConnectionService.ACTION_CALL_DISCONNECT -> "ended"
            else -> return
        }

        val callId = intent.getStringExtra(
            CallConnectionService.EXTRA_CALL_ID
        ).orEmpty()

        val callerId = intent.getStringExtra(
            CallConnectionService.EXTRA_CALLER_ID
        ).orEmpty()

        if (callId.isEmpty()) {
            println("CN CALL Telecom: ignored action without callId")
            return
        }

        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )

        val editor = prefs.edit()
            .putString(
                "flutter.cn_call_telecom_action",
                action
            )
            .putString(
                "flutter.cn_call_telecom_call_id",
                callId
            )
            .putString(
                "flutter.cn_call_telecom_caller_id",
                callerId
            )

        when (action) {
            "accept", "reject" -> {
                editor
                    .putString(
                        "flutter.cn_call_pending_callkit_action",
                        action
                    )
                    .putString(
                        "flutter.cn_call_pending_callkit_call_id",
                        callId
                    )
                    .putString(
                        "flutter.cn_call_pending_callkit_caller_id",
                        callerId
                    )
            }

            "ended" -> {
                editor
                    .remove("flutter.cn_call_pending_callkit_action")
                    .remove("flutter.cn_call_pending_callkit_call_id")
                    .remove("flutter.cn_call_pending_callkit_caller_id")
            }
        }

        editor.apply()

        println(
            "CN CALL Telecom action received: " +
                "action=$action callId=$callId callerId=$callerId"
        )

        // Start a headless Flutter engine so the existing Dart
        // RtcCallManager/LiveKit logic can process the action without
        // launching MainActivity or displaying Flutter UI.
        if (action == "accept" || action == "reject") {
            startBackgroundFlutter(context)
        }
    }

    private fun startBackgroundFlutter(context: Context) {
        val cache = FlutterEngineCache.getInstance()
        val oldEngine = cache.get(ENGINE_ID)

        if (oldEngine != null) {
            println("CN CALL Telecom: replacing old background Flutter engine")
            cache.remove(ENGINE_ID)
            oldEngine.destroy()
        }

        val engine = FlutterEngine(context.applicationContext)

        GeneratedPluginRegistrant.registerWith(engine)

        cache.put(ENGINE_ID, engine)

        val entrypoint = DartExecutor.DartEntrypoint(
            "flutter_assets",
            "package:mobile/main.dart",
            "telecomBackgroundMain"
        )

        engine.dartExecutor.executeDartEntrypoint(entrypoint)

        println("CN CALL Telecom: headless Flutter engine started")
    }
}
