package com.cncall

import com.cncall.data.UserStore
import com.cncall.model.User
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.request.*
import io.ktor.server.routing.*

import io.ktor.server.websocket.*
import io.ktor.websocket.*
import com.cncall.socket.CallSocketManager

import io.ktor.http.*
import kotlinx.serialization.Serializable
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.serialization.kotlinx.json.*


@Serializable
data class AuthRequest(
    val id:String,
    val password:String
)


fun main(){

    embeddedServer(
        Netty,
        port = 8080,
        host = "0.0.0.0"
    ){

        install(ContentNegotiation){
            json()
        }


        install(WebSockets)


        routing {


            get("/"){
                call.respondText("CN CALL SERVER ONLINE")
            }


            webSocket("/ws/{id}") {

                val id = call.parameters["id"]

                if(id == null){
                    close()
                    return@webSocket
                }


                CallSocketManager.addUser(
                    id,
                    this
                )


                try {

                    for(frame in incoming){

                        if(frame is Frame.Text){

                            val text = frame.readText()


                            if(text.startsWith("CALL_REQUEST:")){

                                val target =
                                    text.removePrefix("CALL_REQUEST:")


                                CallSocketManager.sendTo(
                                    target,
                                    "INCOMING_CALL:$id"
                                )

                            }

                        }

                    }


                } finally {

                    CallSocketManager.removeUser(id)

                }

            }




            post("/register"){

                val request = call.receive<AuthRequest>()

                val result = UserStore.register(
                    User(
                        request.id,
                        request.password
                    )
                )


                if(result){
                    call.respondText("REGISTER_OK")
                }else{
                    call.respondText(
                        "USER_EXISTS",
                        status = HttpStatusCode.BadRequest
                    )
                }

            }



            post("/login"){

                val request = call.receive<AuthRequest>()

                val result = UserStore.login(
                    request.id,
                    request.password
                )


                if(result){
                    call.respondText("LOGIN_OK")
                }else{
                    call.respondText(
                        "LOGIN_FAILED",
                        status = HttpStatusCode.Unauthorized
                    )
                }

            }


        }


    }.start(wait=true)

}
