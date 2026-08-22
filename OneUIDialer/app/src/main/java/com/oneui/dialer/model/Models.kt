package com.oneui.dialer.model

data class Contact(
    val id: String,
    val name: String,
    val phoneNumber: String,
    val isFavorite: Boolean = false
)

data class CallLog(
    val id: String,
    val nameOrNumber: String,
    val time: String,
    val type: CallType,
    val simCard: String? = null
)

enum class CallType {
    OUTGOING, INCOMING, MISSED
}
