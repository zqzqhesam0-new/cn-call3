package com.example.mobile

import android.os.Bundle
import android.content.Intent
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "cn_call/call"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        TelecomHelper.register(this)

        persistCallKitIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        persistCallKitIntent(intent)
    }

    private fun persistCallKitIntent(intent: Intent?) {
        val data = intent?.getBundleExtra("EXTRA_CALLKIT_CALL_DATA") ?: return
        val extra = data.getSerializable("EXTRA_CALLKIT_EXTRA") as? HashMap<*, *>
        val callId = data.getString("EXTRA_CALLKIT_ID")
            ?: extra?.get("callId")?.toString()
            ?: return
        val callerId = data.getString("EXTRA_CALLKIT_HANDLE")
            ?: extra?.get("callerId")?.toString()
            ?: ""
        val callerName = data.getString("EXTRA_CALLKIT_NAME_CALLER")
            ?: extra?.get("callerName")?.toString()
            ?: "CN CALL"
        val targetId = extra?.get("targetId")?.toString() ?: ""
        val action = when {
            intent.action?.endsWith("ACTION_CALL_ACCEPT") == true -> "accept"
            intent.action?.endsWith("ACTION_CALL_DECLINE") == true -> "reject"
            intent.action?.endsWith("ACTION_CALL_ENDED") == true -> "ended"
            else -> "incoming"
        }

        if (action == "ended") {
            markCallEnded(callId)
            return
        }
        if (isCallEnded(callId)) return

        val stateJson = JSONObject().apply {
            put("call_id", callId)
            put("caller_id", callerId)
            put("caller_name", callerName)
            put("target_id", targetId)
            put("state", action)
            put("accepted", action == "accept")
            put("rejected", action == "reject")
            put("cancelled", false)
        }

        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putString("flutter.cn_call_pending_callkit_action", action)
            .putString("flutter.cn_call_pending_callkit_call_id", callId)
            .putString("flutter.cn_call_pending_callkit_caller_id", callerId)
            .putString("flutter.pending_incoming_call", stateJson.toString())
            .apply()
    }

    private fun markCallEnded(callId: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val endedIds = endedCallIds(prefs).toMutableList()
        endedIds.remove(callId)
        endedIds.add(callId)
        if (endedIds.size > 32) {
            endedIds.subList(0, endedIds.size - 32).clear()
        }

        val editor = prefs.edit().putString(
            "flutter.cn_call_ended_call_ids_v2",
            JSONArray(endedIds).toString()
        )
        val pending = prefs.getString("flutter.pending_incoming_call", null)
        val pendingId = try {
            JSONObject(pending ?: "{}").optString("call_id")
        } catch (_: Exception) {
            ""
        }
        if (pendingId == callId) {
            editor.remove("flutter.pending_incoming_call")
        }
        if (prefs.getString("flutter.cn_call_pending_callkit_call_id", null) == callId) {
            editor.remove("flutter.cn_call_pending_callkit_action")
                .remove("flutter.cn_call_pending_callkit_caller_id")
                .remove("flutter.cn_call_pending_callkit_call_id")
                .remove("flutter.cn_call_pending_callkit_target_id")
        }
        editor.apply()
    }

    private fun isCallEnded(callId: String): Boolean {
        return endedCallIds(
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        ).contains(callId)
    }

    private fun endedCallIds(prefs: android.content.SharedPreferences): List<String> {
        val encoded = prefs.getString("flutter.cn_call_ended_call_ids_v2", "[]")
        return try {
            val values = JSONArray(encoded ?: "[]")
            List(values.length()) { index -> values.optString(index).trim() }
                .filter { it.isNotEmpty() }
        } catch (_: Exception) {
            emptyList()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "showIncomingCall" -> {
                    result.success(true)
                }

                "openTelecomSettings" -> {
                    startActivity(
                        Intent(android.telecom.TelecomManager.ACTION_CHANGE_PHONE_ACCOUNTS)
                    )
                    result.success(true)
                }

                "disconnectTelecomCall" -> {
                    val callId = call.argument<String>("callId").orEmpty()

                    if (callId.isEmpty()) {
                        result.success(false)
                    } else {
                        CallConnectionService.disconnectCall(callId)
                        result.success(true)
                    }
                }

                "addIncomingTelecomCall" -> {
                    val callerId = call.argument<String>("callerId").orEmpty()
                    val callerName = call.argument<String>("callerName").orEmpty()
                    val callId = call.argument<String>("callId").orEmpty()

                    if (callerId.isEmpty() || callId.isEmpty()) {
                        result.success(false)
                    } else {
                        try {
                            TelecomHelper.addIncomingCall(
                                context = this,
                                callerId = callerId,
                                callerName = callerName.ifEmpty { "CN CALL" },
                                callId = callId,
                            )
                            result.success(true)
                        } catch (e: SecurityException) {
                            println(
                                "CN CALL Telecom: incoming call rejected: $e"
                            )
                            result.success(false)
                        } catch (e: Exception) {
                            println(
                                "CN CALL Telecom: incoming call failed: $e"
                            )
                            result.success(false)
                        }
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
