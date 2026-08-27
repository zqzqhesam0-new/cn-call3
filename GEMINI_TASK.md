You have permission to modify the CN CALL project.

IMPORTANT:
- Create a full backup before any modification.
- Keep all .gz backup files untouched.
- Do not break existing working call functionality.
- Make changes carefully and verify after each major step.

Main goal:
Transform CN CALL into a production-quality application:
- Very lightweight.
- Very fast.
- Smooth call experience similar to WhatsApp in reliability and speed (not copying UI).
- No freezes, crashes, delays, race conditions, or synchronization problems.

Complete audit and optimization:

Check and fix anything causing:
- UI freezing.
- Slow call screen opening.
- Delayed accept/reject/cancel.
- WebSocket conflicts.
- LiveKit connection delays.
- Memory leaks.
- Duplicate listeners.
- Duplicate streams.
- Unnecessary rebuilds.
- Blocking operations on the UI thread.
- Bad state management.
- Race conditions.

Priority 1: Call system reliability
Test and improve:
- Incoming call.
- Accept call.
- Reject call.
- Cancel call.
- Hangup.
- Reconnect.
- Background app.
- Terminated app.

Priority 2: Performance
Optimize:
- Instant call screen opening.
- Fast signaling.
- Async operations.
- Remove unnecessary waits.
- Reduce startup overhead.

Priority 3: Synchronization
Prevent:
- Multiple WebSocket sessions.
- Duplicate calls.
- Old/stale call states.
- FCM and CallKit conflicts.
- State race conditions.

Priority 4: Code quality
- Remove duplicated logic.
- Fix small issues.
- Improve architecture where safe.
- Keep code clean and maintainable.

Logging:
Add detailed logs with:
- Timestamp.
- call_id.
- User IDs.
- WebSocket state.
- LiveKit state.
- FCM events.
- Call state transitions.
- Errors with stack traces.

Recovery:
If anything fails:
- Logs must identify the exact failure point.
- Save progress.
- Continue from the last stable point.

Progress tracking:
Always read and update:
GEMINI_PROGRESS.md

Before every major change:
- Explain what will change.
- Explain why.
- Backup first.

After changes run:
- flutter analyze
- flutter test (if available)
- build checks

Do a complete optimization pass.
Do not stop after finding one issue.
