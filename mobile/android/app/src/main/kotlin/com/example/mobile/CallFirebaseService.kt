package com.example.mobile

import android.content.Intent
import android.os.Bundle
import org.json.JSONObject
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver
import com.hiennv.flutter_callkit_incoming.CallkitConstants

class CallFirebaseService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {

        val type = message.data["type"]

            if (type == "call_cancelled") {
                val callId = message.data["call_id"] ?: return
                val data = Bundle().apply {
                    putString(CallkitConstants.EXTRA_CALLKIT_ID, callId)
                }
                sendBroadcast(
                    CallkitIncomingBroadcastReceiver.getIntentEnded(this, data)
                )
                getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                    .edit()
                    .remove("flutter.pending_incoming_call")
                    .apply()
                return
            }

        if (type != "incoming_call") {
            return
        }

        val callerName =
            message.data["caller_name"]
                ?: "CN CALL"

        val callerId =
            message.data["caller_id"]
                ?: message.data["from_id"]
                ?: ""

        if (callerId.isEmpty()) {
            return
        }

        val callId =
            message.data["call_id"] ?: return
        val targetId = message.data["target_id"] ?: ""

        saveCallState(
            callId = callId,
            callerId = callerId,
            callerName = callerName,
            targetId = targetId,
            state = "incoming"
        )

        val data = Bundle().apply {

            putString(
                CallkitConstants.EXTRA_CALLKIT_ID,
                callId
            )

            putString(
                CallkitConstants.EXTRA_CALLKIT_NAME_CALLER,
                callerName
            )

            putString(
                CallkitConstants.EXTRA_CALLKIT_APP_NAME,
                "CN CALL"
            )

            putString(
                CallkitConstants.EXTRA_CALLKIT_HANDLE,
                callerId
            )

            putString(
                CallkitConstants.EXTRA_CALLKIT_AVATAR,
                ""
            )

            putInt(
                CallkitConstants.EXTRA_CALLKIT_TYPE,
                0
            )

            putLong(
                CallkitConstants.EXTRA_CALLKIT_DURATION,
                30000L
            )

            putString(
                CallkitConstants.EXTRA_CALLKIT_TEXT_ACCEPT,
                "قبول"
            )

            putString(
                CallkitConstants.EXTRA_CALLKIT_TEXT_DECLINE,
                "رفض"
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_IS_SHOW_FULL_LOCKED_SCREEN,
                true
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_IS_IMPORTANT,
                true
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_IS_FULL_SCREEN,
                true
            )

            putString(
                CallkitConstants.EXTRA_CALLKIT_ACTION_FROM,
                "notification"
            )

            putSerializable(
                CallkitConstants.EXTRA_CALLKIT_EXTRA,
                hashMapOf(
                    "callId" to callId,
                    "callerId" to callerId,
                    "callerName" to callerName,
                    "targetId" to targetId
                )
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_SHOW,
                true
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_CALLBACK_SHOW,
                true
            )

            putInt(
                CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_COUNT,
                1
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_CALLING_SHOW,
                false
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_IS_CUSTOM_NOTIFICATION,
                false
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_IS_SHOW_LOGO,
                false
            )

            putBoolean(
                CallkitConstants.EXTRA_CALLKIT_IS_SHOW_CALL_ID,
                false
            )
        }

        val intent =
            CallkitIncomingBroadcastReceiver.getIntentIncoming(
                this,
                data
            )

        sendBroadcast(intent)

        println(
            "CN CALL: CallKit incoming broadcast sent. " +
                "callerId=$callerId callerName=$callerName"
        )
    }

    private fun saveCallState(
        callId: String,
        callerId: String,
        callerName: String,
        targetId: String,
        state: String
    ) {
        val stateJson = JSONObject().apply {
            put("call_id", callId)
            put("caller_id", callerId)
            put("caller_name", callerName)
            put("target_id", targetId)
            put("state", state)
            put("accepted", false)
            put("rejected", false)
            put("cancelled", false)
        }

        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putString("flutter.pending_incoming_call", stateJson.toString())
            .apply()
    }
}
