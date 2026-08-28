package com.example.mobile

import android.content.Intent
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import java.util.concurrent.ConcurrentHashMap

class CallConnectionService : ConnectionService() {

    companion object {
        const val ACTION_CALL_ACCEPT = "com.example.mobile.CN_CALL_ACCEPT"
        const val ACTION_CALL_REJECT = "com.example.mobile.CN_CALL_REJECT"
        const val ACTION_CALL_DISCONNECT = "com.example.mobile.CN_CALL_DISCONNECT"

        const val EXTRA_CALL_ID = "call_id"
        const val EXTRA_CALLER_ID = "caller_id"
        const val EXTRA_CALLER_NAME = "caller_name"

        private val ACTIVE_CONNECTIONS =
            ConcurrentHashMap<String, Connection>()

        fun disconnectCall(callId: String) {
            val id = callId.trim()
            if (id.isEmpty()) return

            val connection = ACTIVE_CONNECTIONS.remove(id) ?: return

            println(
                "CN CALL Telecom: remote disconnect callId=$id"
            )

            try {
                connection.setDisconnected(
                    DisconnectCause(DisconnectCause.REMOTE)
                )
            } catch (e: Exception) {
                println(
                    "CN CALL Telecom: setDisconnected failed: $e"
                )
            }

            try {
                connection.destroy()
            } catch (e: Exception) {
                println(
                    "CN CALL Telecom: destroy failed: $e"
                )
            }
        }
    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle,
        request: ConnectionRequest
    ): Connection {

        val extras: Bundle = request.extras ?: Bundle()

        val callId = extras.getString(EXTRA_CALL_ID).orEmpty()
        val callerId =
            request.address?.schemeSpecificPart
                ?: extras.getString(EXTRA_CALLER_ID).orEmpty()

        val callerName =
            extras.getString(EXTRA_CALLER_NAME)
                ?.trim()
                .orEmpty()
                .ifEmpty { "CN CALL" }

        println(
            "CN CALL Telecom: onCreateIncomingConnection " +
                "callId=$callId callerId=$callerId"
        )

        val connection = object : Connection() {

            override fun onAnswer() {
                super.onAnswer()

                setActive()

                sendCallAction(
                    ACTION_CALL_ACCEPT,
                    callId,
                    callerId
                )
            }

            override fun onReject() {
                sendCallAction(
                    ACTION_CALL_REJECT,
                    callId,
                    callerId
                )

                setDisconnected(
                    DisconnectCause(DisconnectCause.REJECTED)
                )
                if (callId.isNotEmpty()) {
                    ACTIVE_CONNECTIONS.remove(callId)
                }
                destroy()
            }

            override fun onDisconnect() {
                sendCallAction(
                    ACTION_CALL_DISCONNECT,
                    callId,
                    callerId
                )

                setDisconnected(
                    DisconnectCause(DisconnectCause.LOCAL)
                )
                if (callId.isNotEmpty()) {
                    ACTIVE_CONNECTIONS.remove(callId)
                }
                destroy()
            }
        }

        if (callId.isNotEmpty()) {
            ACTIVE_CONNECTIONS[callId] = connection
        }

        connection.setAudioModeIsVoip(true)

        connection.setAddress(
            request.address,
            android.telecom.TelecomManager.PRESENTATION_ALLOWED
        )

        connection.setCallerDisplayName(
            callerName,
            android.telecom.TelecomManager.PRESENTATION_ALLOWED
        )

        connection.setRinging()

        return connection
    }

    private fun sendCallAction(
        action: String,
        callId: String,
        callerId: String
    ) {
        val intent = Intent(
            this@CallConnectionService,
            TelecomCallActionReceiver::class.java
        ).apply {
            this.action = action
            putExtra(EXTRA_CALL_ID, callId)
            putExtra(EXTRA_CALLER_ID, callerId)
        }

        sendBroadcast(intent)
    }
}
