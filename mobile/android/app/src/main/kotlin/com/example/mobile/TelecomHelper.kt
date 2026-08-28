package com.example.mobile

import android.content.ComponentName
import android.content.Context
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager

object TelecomHelper {

    private const val ACCOUNT_ID = "cn_call"

    fun register(context: Context) {
        val telecomManager =
            context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager

        val component = ComponentName(
            context,
            CallConnectionService::class.java
        )

        val handle = PhoneAccountHandle(
            component,
            ACCOUNT_ID
        )

        val account = PhoneAccount.builder(
            handle,
            "CN CALL"
        )
            .setCapabilities(
                PhoneAccount.CAPABILITY_CALL_PROVIDER
            )
            .addSupportedUriScheme("sip")
            .build()

        telecomManager.registerPhoneAccount(account)
    }

    fun isEnabled(context: Context): Boolean {
        val telecomManager =
            context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager

        return telecomManager
            .getPhoneAccount(getHandle(context))
            ?.isEnabled == true
    }

    fun addIncomingCall(
        context: Context,
        callerId: String,
        callerName: String,
        callId: String,
    ) {
        val telecomManager =
            context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager

        val handle = getHandle(context)

        val extras = android.os.Bundle().apply {
            putParcelable(
                TelecomManager.EXTRA_INCOMING_CALL_ADDRESS,
                android.net.Uri.fromParts("sip", callerId, null)
            )
            putString(CallConnectionService.EXTRA_CALL_ID, callId)
            putString(CallConnectionService.EXTRA_CALLER_ID, callerId)
            putString(CallConnectionService.EXTRA_CALLER_NAME, callerName)
        }

        telecomManager.addNewIncomingCall(handle, extras)
    }

    fun getHandle(context: Context): PhoneAccountHandle {
        val component = ComponentName(
            context,
            CallConnectionService::class.java
        )

        return PhoneAccountHandle(
            component,
            ACCOUNT_ID
        )
    }
}
