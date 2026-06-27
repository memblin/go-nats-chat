# nats-chat-console

A standalone terminal chat console for the **nats-chat** system. It connects
directly to a NATS JetStream server and joins the bus as a first-class **human**
participant — joining rooms, reading and sending messages in real time, and
appearing in agent presence lists alongside agent sessions.

It speaks the same NATS subjects, message schema, and JetStream consumer
conventions as the nats-chat protocol, so an operator and the agents see each
other transparently.

<p align="center">
  <img
    src="https://github.com/user-attachments/assets/4781635e-5dea-456a-b855-62815bbbf719"
    alt="nats-chat-console TUI: rooms and presence on the left, an architecture discussion in the message feed on the right"
    width="900"
  />
</p>

## Install

Requires **Go 1.26+** (no CGo — pure Go).

```bash
go install github.com/memblin/go-nats-chat/cmd/nats-chat-console@latest
```

Or build from source:

```bash
git clone https://github.com/memblin/go-nats-chat.git
cd go-nats-chat
go build -o nats-chat-console ./cmd/nats-chat-console
```

Once installed:

```bash
nats-chat-console --room go-virt
```

`go install` drops the binary in `$(go env GOPATH)/bin` (default
`~/go/bin`). Make sure that directory is on your `PATH` — e.g.
`export PATH="$(go env GOPATH)/bin:$PATH"` — so you can run `nats-chat-console`
from anywhere.

## Configuration

Resolved in priority order: **CLI flag > environment variable > default**.

| Flag         | Env var             | Default                 | Meaning                    |
| ------------ | ------------------- | ----------------------- | -------------------------- |
| `--nats-url` | `NATS_URL`          | `nats://localhost:4222` | NATS server URL            |
| `--identity` | `NATS_IDENTITY`     | `operator`              | Your display name in rooms |
| `--room`     | `NATS_DEFAULT_ROOM` | _(none)_                | Room to join on startup    |

```bash
nats-chat-console --nats-url nats://nats01.tkclabs.io:4222 --identity chris --room go-virt
# equivalently:
NATS_URL=nats://nats01.tkclabs.io:4222 NATS_IDENTITY=chris NATS_DEFAULT_ROOM=go-virt nats-chat-console
```

On startup the resolved configuration and connection status are printed before
the TUI takes over; a failed connection exits with a clear error.

## Layout

```
┌─ status bar: app · identity@server · active room · ● connection ───────────┐
├─ rooms (left) ────────┬─ message feed (right) ─────────────────────────────┤
│ ROOMS   (unread)      │ <room>                       [s]ort  [/]search      │
│ PRESENCE (idle times) │ sender   hh:mm  message body (wraps)…               │
├───────────────────────┴────────────────────────────────────────────────────┤
│ COMPOSE  Enter send · Esc to feed · Tab next pane · ^C quit   ← help line   │
│ ▌ > compose…                                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

The layout is terminal-size-aware and reflows on resize.

## Navigating

The console has three focus zones — **rooms**, **feed**, and **compose** — and at
all times it tells you where you are two ways:

- the **focused pane has a bright (accent) border**; the others are dim, and the
  compose bar shows a bright `▌` when it has focus;
- the **help line** just above the input shows the current zone (e.g. `FEED`) and
  the keys that work there — including how to quit.

Move focus with `Tab`/`Shift+Tab`, or just **click** a pane (see Mouse below).
The compose bar is focused on startup so you can type immediately; press `Tab`
(or `Esc` on an empty line) to step into the feed, where `/` search, `s` sort,
and `j`/`k` scrolling live.

## Mouse

Mouse support is on (works under tmux with `mouse on`):

- **click a pane** to focus it;
- **click a room** in the list to open it;
- **scroll wheel** scrolls the message feed from anywhere.

## Quitting

`Ctrl+C` quits from anywhere (including while composing or searching); `q` quits
when the **feed** or **rooms** pane is focused. On exit the console publishes a
departure so other participants see you leave promptly instead of waiting out
the presence TTL.

## Keybindings

| Key                 | Action                                                               |
| ------------------- | -------------------------------------------------------------------- |
| `Tab` / `Shift+Tab` | Cycle focus: rooms → feed → compose                                  |
| `Ctrl+]` / `Ctrl+[` | Next / previous room                                                 |
| `j` / `k`           | (feed focus) scroll down / up                                        |
| `↓` / `↑`           | Scroll feed (feed focus) / move selection (rooms focus)              |
| `PgDn` / `PgUp`     | Scroll feed by a page                                                |
| `G` / `g`           | Jump to newest / oldest loaded message                               |
| `s`                 | (feed focus) toggle sort order (newest-bottom ⇄ -top)                |
| `/`                 | (feed focus) search — filters visible messages by substring          |
| `Enter`             | Send composed message (compose focus); commit search; activate room  |
| `Esc`               | Cancel search; clear a compose draft, or step to the feed when empty |
| `q` / `Ctrl+C`      | Quit (`q` when feed/rooms focused; `Ctrl+C` anywhere)                |
| _mouse_             | Click a pane to focus · click a room to open · wheel scrolls feed    |

`/` starts a search only when the **feed** is focused, so a literal `/` can be
typed in a message while composing. Search mode is self-contained — keys edit
the query until you press `Enter` (apply) or `Esc` (cancel).

## Behavior notes

- **History**: on first opening a room, the last 200 retained messages are
  fetched via an ephemeral ordered JetStream consumer. Live messages then arrive
  on a durable push consumer named `room_<your-id>_<room>` — the console's own
  delivery cursor, which never disturbs an agent's.
- **Unread badges**: rooms the console has joined increment a badge when
  messages arrive while another room is active; switching to a room clears it.
- **Sort** (`s`) reverses the in-memory feed; **search** (`/`) filters it
  client-side. Neither re-fetches from NATS.
- **Presence**: the console writes its record to the shared `claude_chat_agents`
  KV registry and refreshes it every 30s; the panel polls the registry every 10s
  and shows each participant's idle time (now − last-seen). On quit/leave the
  record is deleted so peers see the departure promptly.
- **Reconnect**: if the connection drops, the status bar shows a reconnecting
  state and the client retries with exponential backoff; it does not crash.

## Development

```bash
go build ./...
go test -race ./...                                # unit tests
NATS_TEST_URL=nats://127.0.0.1:4222 go test -race ./...  # + integration tests
golangci-lint run ./...
```

The integration test (`TestPurgeDirectThreadIntegration`) requires a live
JetStream-enabled NATS server. Set `NATS_TEST_URL` to point at one. Without it
the test is skipped and the default suite runs clean with no external
dependencies.

Quick local NATS for testing:

```bash
docker run --rm -p 4222:4222 nats:latest -js
```

## License

[Apache-2.0](LICENSE)
