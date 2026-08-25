package com.example.mobile

import android.telecom.Connection
import android.telecom.ConnectionService
import android.telecom.ConnectionRequest
import android.telecom.PhoneAccountHandle

class CallConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle,
        request: ConnectionRequest
    ): Connection {

        val connection = object : Connection() {

            override fun onAnswer() {
                super.onAnswer()
            }

            override fun onReject() {
                setDisconnected(
                    android.telecom.DisconnectCause(
                        android.telecom.DisconnectCause.REJECTED
                    )
                )
                destroy()
            }

            override fun onDisconnect() {
                setDisconnected(
                    android.telecom.DisconnectCause(
                        android.telecom.DisconnectCause.LOCAL
                    )
                )
                destroy()
            }
        }

        connection.setRinging()

        return connection
    }
}
