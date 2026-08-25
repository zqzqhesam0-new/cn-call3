from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from pathlib import Path
import hashlib
import hmac
import json
import os
import re
import sqlite3
import time
import shutil
import uuid

import firebase_admin
from firebase_admin import credentials, messaging


app = FastAPI(title="CN CALL Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


BASE_DIR = Path(__file__).resolve().parent
VOLUME_DIR = Path("/app/data")
DB_PATH = VOLUME_DIR / "cn_call.db"
LEGACY_DB_PATH = BASE_DIR / "cn_call.db"

VOLUME_DIR.mkdir(parents=True, exist_ok=True)

if not DB_PATH.exists() and LEGACY_DB_PATH.exists():
    shutil.copy2(LEGACY_DB_PATH, DB_PATH)
    print("[CN CALL][DB] Legacy database migrated to Railway Volume")


connections: dict[str, WebSocket] = {}

FCM_TOKENS: dict[str, str] = {}

firebase_key = BASE_DIR / "secrets" / "firebase-service-account.json"
firebase_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")

if not firebase_admin._apps:
    if firebase_json:
        cred = credentials.Certificate(
            __import__("json").loads(firebase_json)
        )
        firebase_admin.initialize_app(cred)
    elif firebase_key.exists():
        cred = credentials.Certificate(str(firebase_key))
        firebase_admin.initialize_app(cred)



# ============================================================
# DATABASE
# ============================================================

def get_db():
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    return db


def init_db():
    db = get_db()

    db.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            password_salt TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )

    db.execute(
        """
        CREATE TABLE IF NOT EXISTS fcm_tokens (
            user_id TEXT PRIMARY KEY,
            token TEXT NOT NULL,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )

    db.commit()
    db.close()


init_db()


def load_fcm_tokens():
    db = get_db()
    rows = db.execute(
        "SELECT user_id, token FROM fcm_tokens"
    ).fetchall()
    db.close()

    for row in rows:
        FCM_TOKENS[row["user_id"]] = row["token"]


load_fcm_tokens()


# ============================================================
# PASSWORD SECURITY
# ============================================================

def hash_password(password: str, salt: bytes | None = None):
    if salt is None:
        salt = os.urandom(16)

    password_hash = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        200_000,
    )

    return (
        password_hash.hex(),
        salt.hex(),
    )


def verify_password(
    password: str,
    password_hash: str,
    password_salt: str,
):
    try:
        salt = bytes.fromhex(password_salt)
    except ValueError:
        return False

    calculated, _ = hash_password(password, salt)

    return hmac.compare_digest(
        calculated,
        password_hash,
    )


# ============================================================
# MODELS
# ============================================================

class RegisterRequest(BaseModel):
    user_id: str
    username: str
    password: str


class LoginRequest(BaseModel):
    user_id: str
    password: str


class FcmTokenRequest(BaseModel):
    user_id: str
    token: str



# ============================================================
# FCM TOKEN
# ============================================================

@app.post("/fcm-token")
async def save_fcm_token(request: FcmTokenRequest):
    user_id = request.user_id.strip()
    token = request.token.strip()

    if not user_id or not token:
        return {
            "success": False,
            "message": "بيانات FCM غير صالحة",
        }

    FCM_TOKENS[user_id] = token
    print("SAVED FCM TOKEN USER:", user_id)

    db = get_db()
    db.execute(
        """
        INSERT INTO fcm_tokens (user_id, token, updated_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(user_id)
        DO UPDATE SET
            token=excluded.token,
            updated_at=CURRENT_TIMESTAMP
        """,
        (user_id, token),
    )
    db.commit()
    db.close()

    return {
        "success": True,
        "message": "تم حفظ FCM Token",
    }


# ============================================================
# BASIC
# ============================================================

@app.get("/")
async def root():
    return {
        "app": "CN CALL",
        "status": "online",
    }




@app.get("/fcm-debug")
def fcm_debug():
    return {
        "memory": FCM_TOKENS,
    }

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "users": len(connections),
    }


# ============================================================
# REGISTER
# ============================================================

@app.post("/register")
async def register(request: RegisterRequest):
    user_id = request.user_id.strip()
    username = request.username.strip()
    password = request.password

    if not user_id:
        return {
            "success": False,
            "message": "ID المستخدم مطلوب",
        }

    if not re.fullmatch(r"\d+", user_id):
        return {
            "success": False,
            "message": "ID المستخدم يجب أن يكون أرقامًا فقط",
        }

    if len(username) < 3:
        return {
            "success": False,
            "message": "اسم المستخدم يجب أن يكون 3 أحرف على الأقل",
        }

    if len(password) < 6:
        return {
            "success": False,
            "message": "كلمة المرور يجب أن تكون 6 أحرف على الأقل",
        }

    db = get_db()

    existing = db.execute(
        "SELECT user_id FROM users WHERE user_id = ?",
        (user_id,),
    ).fetchone()

    if existing is not None:
        db.close()

        return {
            "success": False,
            "message": "ID المستخدم مستخدم بالفعل",
        }

    password_hash, password_salt = hash_password(password)

    db.execute(
        """
        INSERT INTO users (
            user_id,
            username,
            password_hash,
            password_salt
        )
        VALUES (?, ?, ?, ?)
        """,
        (
            user_id,
            username,
            password_hash,
            password_salt,
        ),
    )

    db.commit()
    db.close()

    return {
        "success": True,
        "message": "تم إنشاء الحساب بنجاح",
        "user": {
            "user_id": user_id,
            "username": username,
        },
    }


# ============================================================
# LOGIN
# ============================================================

@app.post("/login")
async def login(request: LoginRequest):
    user_id = request.user_id.strip()
    password = request.password

    db = get_db()

    user = db.execute(
        """
        SELECT
            user_id,
            username,
            password_hash,
            password_salt
        FROM users
        WHERE user_id = ?
        """,
        (user_id,),
    ).fetchone()

    db.close()

    if user is None:
        return {
            "success": False,
            "message": "ID المستخدم أو كلمة المرور غير صحيحة",
        }

    if not verify_password(
        password,
        user["password_hash"],
        user["password_salt"],
    ):
        return {
            "success": False,
            "message": "ID المستخدم أو كلمة المرور غير صحيحة",
        }

    return {
        "success": True,
        "message": "تم تسجيل الدخول بنجاح",
        "user": {
            "user_id": user["user_id"],
            "username": user["username"],
        },
    }


# ============================================================
# USER LOOKUP
# ============================================================

@app.get("/users/{user_id}")
async def get_user(user_id: str):
    db = get_db()

    user = db.execute(
        """
        SELECT user_id, username, created_at
        FROM users
        WHERE user_id = ?
        """,
        (user_id.strip(),),
    ).fetchone()

    db.close()

    if user is None:
        return {
            "success": False,
            "message": "المستخدم غير موجود",
        }

    return {
        "success": True,
        "user": {
            "user_id": user["user_id"],
            "username": user["username"],
            "online": user["user_id"] in connections,
        },
    }



# ============================================================
# FCM NOTIFICATIONS
# ============================================================

def send_call_notification(
    target_id: str,
    caller_id: str,
    caller_name: str,
    call_id: str,
    message_type: str = "incoming_call",
):
    token = FCM_TOKENS.get(target_id)

    print("FCM TARGET:", target_id)
    print("FCM TOKEN FOUND:", bool(token))

    if not token:
        db = get_db()
        row = db.execute(
            "SELECT token FROM fcm_tokens WHERE user_id = ?",
            (target_id,),
        ).fetchone()
        db.close()

        if row:
            token = row["token"]
            FCM_TOKENS[target_id] = token

    if not token:
        return

    if not firebase_admin._apps:
        return

    try:
        message = messaging.Message(
            token=token,
            data={
                "type": message_type,
                "call_id": call_id,
                "caller_id": caller_id,
                "caller_name": caller_name,
                "target_id": target_id,
            },
            android=messaging.AndroidConfig(
                priority="high",
            ),
        )

        response = messaging.send(message)
        print('FCM SENT:', response)

    except Exception as e:
        print(f"FCM send error: {e}")


# ============================================================
# WEBSOCKET / CALLS
# ============================================================


@app.get("/turn-credentials")
async def get_turn_credentials():
    turn_url = os.getenv("TURN_URL", "").strip()
    turn_username = os.getenv("TURN_USERNAME", "").strip()
    turn_password = os.getenv("TURN_PASSWORD", "").strip()

    if not turn_url or not turn_username or not turn_password:
        return {
            "success": False,
            "message": "TURN credentials are not configured",
        }

    base_url = turn_url
    if not base_url.startswith("turn:"):
        base_url = f"turn:{base_url}"

    return {
        "success": True,
        "iceServers": [
            {
                "urls": [
                    f"{base_url}?transport=udp",
                    f"{base_url}?transport=tcp",
                ],
                "username": turn_username,
                "credential": turn_password,
            }
        ],
    }


@app.websocket("/ws/{user_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    user_id: str,
):
    if user_id in connections:
        try:
            await connections[user_id].close()
        except Exception:
            pass

        del connections[user_id]

    await websocket.accept()

    connections[user_id] = websocket

    try:
        await websocket.send_json({
            "type": "connected",
            "user_id": user_id,
        })

        while True:
            message = await websocket.receive_json()
            print('CALL MESSAGE:', message)

            target_id = str(
                message.get("target_id", "")
            ).strip()

            message_type = str(message.get("type", "")).strip()
            call_id = str(message.get("call_id", "")).strip()

            ring_expires_at = message.get("ring_expires_at")

            if message_type == "call" and not call_id:
                call_id = str(uuid.uuid4())

            if message_type == "call" and not ring_expires_at:
                ring_expires_at = int(time.time() * 1000) + 90000

            if call_id or ring_expires_at:
                message = {
                    **message,
                    "call_id": call_id,
                    "ring_expires_at": ring_expires_at,
                }

            if target_id and target_id in connections:
                await connections[target_id].send_json({
                    **message,
                    "from_id": user_id,
                })

            if message_type == "call" and call_id:
                await websocket.send_json({
                    "type": "call_started",
                    "call_id": call_id,
                    "target_id": target_id,
                    "from_id": user_id,
                    "ring_expires_at": ring_expires_at,
                })

            if (
                message_type == "call"
                and target_id
                and target_id not in connections
            ):
                caller_name = str(
                    message.get("caller_name", "مستخدم CN CALL")
                )

                send_call_notification(
                    target_id=target_id,
                    caller_id=user_id,
                    caller_name=caller_name,
                    call_id=call_id,
                )

            if (
                message_type in {"call_cancelled", "call_reject"}
                and target_id
                and target_id not in connections
            ):
                send_call_notification(
                    target_id=target_id,
                    caller_id=user_id,
                    caller_name=str(message.get("caller_name", "مستخدم CN CALL")),
                    call_id=call_id,
                    message_type="call_cancelled",
                )

    except WebSocketDisconnect:
        pass

    finally:
        if connections.get(user_id) is websocket:
            del connections[user_id]
# cn-call2 railway test
