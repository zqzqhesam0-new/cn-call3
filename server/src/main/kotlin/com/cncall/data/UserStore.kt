package com.cncall.data

import com.cncall.model.User
import java.sql.DriverManager

object UserStore {

    private const val DB_URL = "jdbc:sqlite:users.db"

    init {
        Class.forName("org.sqlite.JDBC")

        DriverManager.getConnection(DB_URL).use { conn ->
            conn.createStatement().use { stmt ->

                stmt.execute(
                    """
                    CREATE TABLE IF NOT EXISTS users (
                        id TEXT PRIMARY KEY,
                        password TEXT NOT NULL,
                        display_name TEXT NOT NULL DEFAULT ''
                    )
                    """.trimIndent()
                )

                try {
                    stmt.execute(
                        "ALTER TABLE users ADD COLUMN display_name TEXT NOT NULL DEFAULT ''"
                    )
                } catch (_: Exception) {
                    // العمود موجود بالفعل
                }
            }
        }
    }

    fun register(user: User): Boolean {

        DriverManager.getConnection(DB_URL).use { conn ->

            val check = conn.prepareStatement(
                "SELECT id FROM users WHERE id = ?"
            )

            check.setString(1, user.id)

            val result = check.executeQuery()

            if (result.next()) {
                return false
            }

            val insert = conn.prepareStatement(
                """
                INSERT INTO users(id,password,display_name)
                VALUES(?,?,?)
                """.trimIndent()
            )

            insert.setString(1, user.id)
            insert.setString(2, user.password)
            insert.setString(3, user.displayName)

            insert.executeUpdate()

            return true
        }
    }

    fun login(id: String, password: String): Boolean {

        DriverManager.getConnection(DB_URL).use { conn ->

            val stmt = conn.prepareStatement(
                "SELECT id FROM users WHERE id=? AND password=?"
            )

            stmt.setString(1, id)
            stmt.setString(2, password)

            val result = stmt.executeQuery()

            return result.next()
        }
    }

    fun getDisplayName(id: String): String {

        DriverManager.getConnection(DB_URL).use { conn ->

            val stmt = conn.prepareStatement(
                "SELECT display_name FROM users WHERE id=?"
            )

            stmt.setString(1, id)

            val result = stmt.executeQuery()

            return if (result.next()) {
                result.getString("display_name") ?: id
            } else {
                id
            }
        }
    }
}
