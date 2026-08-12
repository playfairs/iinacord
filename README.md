# IINAcord

Discord Rich Presence for (IINA)[https://iina.io/].

---

## What it currently does

- Starts a local IPC server at `/tmp/iinacord.sock` for the IINA plugin to send playback state.
- Monitors the local system for the Discord desktop client. (Currently only checks Stable?)
- Discovers Discord IPC sockets using the documented IPC path order:
  - `$XDG_RUNTIME_DIR/discord-ipc-{n}`
  - `$TMPDIR/discord-ipc-{n}`
  - `$TMP/discord-ipc-{n}`
  - `$TEMP/discord-ipc-{n}`
  - `/tmp/discord-ipc-{n}`
- Connects to Discord over the native Unix socket and performs the Discord IPC handshake.
- Waits for the `READY` event before sending any Rich Presence updates.
- Sends Discord RPC using `opcode = 1` and `cmd = "SET_ACTIVITY"`.
- Uses the IINAcord process PID for the `pid` field in `SET_ACTIVITY`.
- Generates a unique UUID nonce for each `SET_ACTIVITY` command.
- If IINA is running but no playback state is available yet, publishes a placeholder activity: (This is also the only currentl State since I was trying to get the socket itself to work)
  - `details: "Watching IINA"`
  - `state: "Idle"`
  - `type: 3` (Watching)
- Clears Discord Rich Presence with `activity = null` when IINA is not running.

## Current implementation details

- `Sources/IINAcord/App/AppDelegate.swift`
  - Starts the IPC server and Discord monitor.
  - Reads playback messages from `/tmp/iinacord.sock`.
  - Tracks whether IINA is running using `NSWorkspace.shared.runningApplications`.
  - Clears presence when IINA stops.
- `Sources/IINAcord/RPC/DiscordRPC.swift`
  - Handles Discord IPC socket discovery, connection, and framing.
  - Sends the handshake frame with `opcode = 0` and waits for `READY`.
  - Sends `SET_ACTIVITY` frames with `opcode = 1`.
  - Reads complete Discord IPC frames with exact-byte reads.
- `Sources/IINAcord/RPC/DiscordActivity.swift`
  - Converts `PlaybackState` into a Discord activity object.
  - Builds start/end timestamps only when playback is active.

## Notes

- The current app is designed for local Discord desktop IPC, not WebSockets or OAuth.
- The `SET_ACTIVITY` command is the only RPC command currently used.
- The app keeps the Discord connection open and refreshes presence based on IINA state.
- There is a standalone test script at `discord_rpc_test.swift` that demonstrates the same native Discord IPC flow.
 - There is a standalone test script at `discord_rpc_test.swift` that demonstrates the same native Discord IPC flow.
 - Playback integration: when the IINA plugin sends playback updates, IINAcord converts those messages into a Discord `activity` (details, state, timestamps) and issues `SET_ACTIVITY` to update Rich Presence. This wiring is implemented but still undergoing final testing and edge-case handling.
 - Future clients: we may add support for alternative Discord clients (specifically: **[Vesktop](https://vesktop.dev/)**, **[Equibop](https://equibop.org/)**, **[Legcord](https://legcord.app/)**, **[GoofCord](https://github.com/Milkshiift/GoofCord)**, **[Dorion](https://github.com/SpikeHD/Dorion)**) only if they require separate IPC handling. If those clients use the same IPC socket as the official Discord desktop client, no additional work should be necessary.