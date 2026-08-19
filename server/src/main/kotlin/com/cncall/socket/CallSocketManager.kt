package com.cncall.socket

import io.ktor.websocket.*

object CallSocketManager {

    private val users = mutableMapOf<String, DefaultWebSocketSession>()


    suspend fun addUser(
        id: String,
        session: DefaultWebSocketSession
    ){

        users[id] = session

    }



    fun removeUser(id:String){

        users.remove(id)

    }



    suspend fun sendTo(
        id:String,
        message:String
    ){

        users[id]?.send(
            Frame.Text(message)
        )

    }


}
