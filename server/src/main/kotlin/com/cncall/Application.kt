package com.cncall

import com.cncall.data.UserStore
import com.cncall.model.User
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.request.*
import io.ktor.server.routing.*
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


        routing {


            get("/"){
                call.respondText("CN CALL SERVER ONLINE")
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
