package com.cncall.data

import com.cncall.model.User

object UserStore {

    private val users = mutableListOf<User>()

    fun register(user: User): Boolean {

        if(users.any { it.id == user.id }){
            return false
        }

        users.add(user)
        return true
    }


    fun login(id:String,password:String):Boolean{

        return users.any {
            it.id == id && it.password == password
        }

    }
}
