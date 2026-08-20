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
import io.ktor.server.plugins.cors.routing.*
import io.ktor.serialization.kotlinx.json.*


@Serializable
data class AuthRequest(
    val id:String,
    val password:String,
    val displayName:String = ""
)


fun main(){

    embeddedServer(
        Netty,
        port = System.getenv("PORT")?.toInt() ?: 8080,
        host = "0.0.0.0"
    ){

        install(CORS){
    anyHost()
    allowHeader("Content-Type")
    allowMethod(io.ktor.http.HttpMethod.Post)
}

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


                                val displayName =
                                    UserStore.getDisplayName(id)

                                CallSocketManager.sendTo(
                                    target,
                                    "INCOMING_CALL:$id:$displayName"
                                )

                            }


                            if(text.startsWith("ACCEPT_CALL:")){

                                val caller =
                                    text.removePrefix("ACCEPT_CALL:")


                                val displayName =
                                    UserStore.getDisplayName(id)

                                CallSocketManager.sendTo(
                                    caller,
                                    "CALL_ACCEPTED:$id:$displayName"
                                )

                            }


                            if(text.startsWith("END_CALL:")){

                                val target =
                                    text.removePrefix("END_CALL:")

                                // Notify the remote party
                                CallSocketManager.sendTo(
                                    target,
                                    "CALL_ENDED:$id"
                                )

                                // Also notify the caller/local party so both sides
                                // leave the call screen and clean up WebRTC.
                                CallSocketManager.sendTo(
                                    id,
                                    "CALL_ENDED:$target"
                                )

                            }


                            if(text.startsWith("OFFER:")){

                                val parts = text.split(":", limit = 3)

                                val target = parts[1]
                                val offer = parts[2]

                                CallSocketManager.sendTo(
                                    target,
                                    "OFFER:$id:$offer"
                                )

                            }


                            if(text.startsWith("ANSWER:")){

                                val parts = text.split(":", limit = 3)

                                val target = parts[1]
                                val answer = parts[2]

                                CallSocketManager.sendTo(
                                    target,
                                    "ANSWER:$id:$answer"
                                )

                            }


                            if(text.startsWith("ICE:")){

                                val parts = text.split(":", limit = 3)

                                val target = parts[1]
                                val ice = parts[2]

                                CallSocketManager.sendTo(
                                    target,
                                    "ICE:$id:$ice"
                                )

                            }


                              if(text.startsWith("REJECT_CALL:")){

                                  val caller =
                                      text.removePrefix("REJECT_CALL:")

                                  CallSocketManager.sendTo(
                                      caller,
                                      "CALL_REJECTED:$id"
                                  )

                                  CallSocketManager.sendTo(
                                      id,
                                      "CALL_ENDED:$caller"
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
                        request.password,
                        request.displayName.ifBlank { request.id }
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
                    val displayName =
                        UserStore.getDisplayName(request.id)

                    call.respondText(
                        "LOGIN_OK:$displayName"
                    )
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
