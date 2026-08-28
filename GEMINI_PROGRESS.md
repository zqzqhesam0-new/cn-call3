# CN CALL Gemini Progress

Project: CN CALL

Goal:
Make the application fast, stable, and production quality.

Rules:
- Backup before risky changes.
- Do not break working call flow.
- Keep all .gz backups.
- Record every modification.

Current Status:
- Flutter cache cleaned.
- Build folders cleaned.
- Investigation: call freeze during accept.

Main Areas:
- rtc_call_manager.dart
- livekit_call.dart
- livekit_token_service.dart
- call_socket.dart
- call_session.dart
- firebase_messaging_service.dart
- server/main.py

Last Completed Step:
-

Current Step:
-

Next Step:
-

Files Modified:
-

Tests Run:
-

Errors Found:
-

Notes:
-

## Android Telecom integration - 2026-08-28
- Created backup: CallConnectionService.kt.before_telecom_buttons_20260828.bak
- TelecomHelper registers CN CALL as a CALL_PROVIDER PhoneAccount.
- Next modification: connect Android Telecom incoming call Connection buttons (answer/reject/disconnect) to CN CALL action events.
- CallKit remains enabled as fallback during this phase.
- Do not remove CallKit until Telecom path is tested on-device.

## Android Telecom action bridge - 2026-08-28
- Backups created before the next major modification.
- CallConnectionService now exposes native accept/reject/disconnect action constants.
- TelecomHelper can register the CN CALL PhoneAccount and submit incoming calls.
- Next step: receive Telecom actions natively without launching MainActivity.
- LiveKit remains Flutter-based; do not open Flutter UI from Telecom button actions.
- Keep CallKit as fallback until Telecom is verified on a real Android device.
