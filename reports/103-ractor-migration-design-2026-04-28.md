---
title: ractor migration design — criome-daemon and nexus-daemon
author: claude (research)
date: 2026-04-28
trigger: Li (2026-04-28) — "I do want to use ractor. do a research on converting the daemons to ractor"
related:
  - tools-documentation/rust/style.md §"Actors"
  - criome/src/{daemon,uds,dispatch}.rs
  - nexus/src/{daemon,connection,criome_link}.rs
  - reports/100-handoff-after-nota-codec-shipping.md §5 (M0 demo wiring)
---

# 103 — ractor migration design for criome-daemon and nexus-daemon

## 0. TL;DR

Both daemons today are **plain `tokio::main` accept-loops** that
`tokio::spawn` a detached task per accepted client. There is no
typed message protocol, no supervision, and shared state in criome
travels via `Arc<Daemon>`. This is fine for M0 and shouldn't be
ripped out under deadline pressure — but the project's chosen
direction (style.md §Actors) is **ractor for any component with
state and a message protocol**, and `ractor = "0.15"` is already
declared in `criome/Cargo.toml` (currently unused).

The proposal below converts each daemon to a small supervision
tree. The shape is conservative — actors only where actors buy
something — and the sync one-shot binaries (`criome-handle-frame`,
`nexus-parse`, `nexus-render`) stay sync because they have no
concurrent state and ractor would be wrong for them.

Concrete shapes:

- **criome-daemon:** `Sema` actor (owns the redb store, serializes
  every frame through one mailbox) + `Listener` actor (UDS accept
  loop) + `Connection` actors (one per accepted client, child of
  the Listener). The Listener supervises Connections; the root
  binary supervises Sema and Listener.
- **nexus-daemon:** `Listener` actor + `Connection` actors. Each
  `Connection` owns a `CriomeLink` directly inside its `State`
  (no separate actor — a `CriomeLink` is single-owner, one
  request/reply at a time, and there's nothing concurrent to
  model). The root binary supervises the Listener.

Migration is staged: criome first (single component to lift),
then nexus once the patterns are settled. The integration test
in `mentci/checks/integration.nix` doesn't change — it pokes the
process from outside, so the inside can be re-architected freely.

The rest of this report justifies and details the above.

---

## 1. Ractor in 5 minutes

The whole crate is approximately Erlang's `gen_server` rewritten
in Rust on top of tokio. The shape that matters:

### 1.1 The `Actor` trait

```rust
#[async_trait]
pub trait Actor: Sized + Send + Sync + 'static {
    type Msg:       Message;            // typed inbox
    type State:     Send + 'static;     // what the actor owns
    type Arguments: Send + 'static;     // construction-time inputs

    async fn pre_start(
        &self,
        myself: ActorRef<Self::Msg>,
        arguments: Self::Arguments,
    ) -> Result<Self::State, ActorProcessingErr>;

    async fn handle(
        &self,
        myself: ActorRef<Self::Msg>,
        message: Self::Msg,
        state:   &mut Self::State,
    ) -> Result<(), ActorProcessingErr>;

    // Optional: post_start, handle_supervisor_evt, post_stop.
}
```

Two things to internalize:

1. **The actor struct itself is read-only configuration.** All
   mutable state lives in `Self::State`, constructed inside
   `pre_start`. The README explicitly notes the ideal is "all
   actor structs would be empty"; everything mutable rides on
   the `&mut Self::State` parameter.
2. **The mailbox is single-threaded.** Every `handle` call for a
   given actor runs sequentially on whichever tokio worker picks
   up the message. There is no `Mutex<State>` because there's
   only ever one writer.

### 1.2 Spawning and supervision

```rust
let (sema_ref, sema_handle) =
    Actor::spawn(Some("sema".into()), SemaActor, sema_args).await?;

let (listener_ref, listener_handle) =
    Actor::spawn_linked(
        sema_ref.get_cell(),  // supervisor
        Some("listener".into()),
        ListenerActor,
        listener_args,
    ).await?;
```

`spawn` is a root spawn; `spawn_linked` adds a parent-child link
so the parent receives `SupervisionEvent`s for child startup,
death, and panic. The parent decides restart-vs-shutdown in its
`handle_supervisor_evt`.

### 1.3 Talking to an actor

`ActorRef<Msg>` is the handle. The methods that matter for our
daemons:

| method                | shape                                        | use                     |
|-----------------------|----------------------------------------------|-------------------------|
| `cast` / `send_message` | fire-and-forget                            | one-way notifications   |
| `call(builder, …)`    | request/response via an `RpcReplyPort`       | "ask" with a typed reply|
| `send_after(d, m)`    | timer                                        | retries / heartbeats    |
| `stop(reason)`        | graceful shutdown after current handle done  | clean teardown          |
| `stop_and_wait`       | as above, but await termination              | sequential shutdown     |
| `kill`                | immediate `Signal::Kill`                     | escalation only         |

`call` is the one that matters most for our daemons — it's how a
listener asks the sema actor "process this frame; here's where to
post the reply." The pattern is:

```rust
let reply: Frame = sema_ref
    .call(|reply_port| SemaMessage::HandleFrame { frame, reply_port }, None)
    .await??;
```

`reply_port` is an `RpcReplyPort<Frame>` the actor consumes once
and sends the reply through; the outer `Result` is the call
machinery, the inner is the actor's own.

### 1.4 Message priority

Ractor processes four queues in priority order (highest first):

1. Signals (`Signal::Kill`).
2. Stop requests (graceful).
3. Supervision events from children.
4. User messages.

So `stop()` jumps the user-message queue; this matters for
shutdown but not for steady-state. A flood of frames from a
client cannot starve a `stop`.

### 1.5 What ractor pulls in

`ractor = "0.15"` depends on tokio (multi-thread + macros + sync
primitives). Per style.md §Actors, this is acceptable everywhere:
"tokio via ractor is just the runtime." We keep the `#[tokio::main]`
in `main.rs`; ractor uses the surrounding tokio runtime.

---

## 2. Current daemon shapes

### 2.1 criome-daemon today

```
main()
  └── tokio::spawn (in Listener::run)
        ├── connection task 1  ──┐
        ├── connection task 2  ──┼── all share Arc<Daemon> { sema: Arc<Sema> }
        └── connection task N  ──┘
```

Concrete files:

- `criome/src/daemon.rs:12` — `Daemon { sema: Arc<Sema> }`,
  sync `handle_frame(&self, frame: Frame) -> Frame`.
- `criome/src/uds.rs:34` — `Listener::run(self, daemon: Arc<Daemon>)`
  is the accept loop; `handle_connection` is the per-connection
  loop reading length-prefixed frames and calling `daemon.handle_frame`.
- `criome/src/dispatch.rs:15` — `Daemon::handle_request` matches
  on the verb and routes to `handle_handshake` / `handle_assert` /
  `handle_query`. Pure sync.

There is **no concurrent state inside `Daemon`** — `Sema` is
`Arc`-shared by reference, not owned by any task, and `redb`
internally handles locking. Today, two connections asserting at
the same time both call `handle_frame` concurrently and redb
serializes them at the storage layer.

### 2.2 nexus-daemon today

```
main()
  └── Daemon::run accept-loop
        └── tokio::spawn  (one per client)
              └── Connection::shuttle
                    ├── read text-to-EOF
                    ├── Parser::next_request loop
                    ├── CriomeLink::open  (paired UDS to criome)
                    ├── CriomeLink::send  (per request, FIFO replies)
                    └── Renderer::into_text + write to client
```

Concrete files:

- `nexus/src/daemon.rs:22` — `Daemon { listen_path, criome_socket_path }`,
  no per-process state.
- `nexus/src/connection.rs:39` — `Connection::shuttle` is a single
  one-shot async fn: read, parse, link, forward, render, write,
  close. Lives until the client closes the write side.
- `nexus/src/criome_link.rs:23` — `CriomeLink { stream: UnixStream }`,
  with `open` (handshake) and `send` (one request → one reply).

Each connection is **fully independent**: its own `CriomeLink`,
its own `Renderer`, its own parser state. Nothing crosses
connection boundaries.

---

## 3. Proposed criome-daemon as ractor

### 3.1 Actor inventory

Three actor types (and one non-actor):

| name              | role                                              | state owned                  |
|-------------------|---------------------------------------------------|------------------------------|
| `SemaActor`       | serializes every signal frame through one mailbox | `Sema` (the redb store)      |
| `ListenerActor`   | UDS accept loop; spawns Connections               | `UnixListener`               |
| `ConnectionActor` | per-client read/write loop                        | `UnixStream`                 |
| `Daemon` (struct) | tiny façade `main` calls; not an actor            | `ActorRef<SemaMessage>` etc. |

The non-actor `Daemon` exists only because style.md §"Methods on
types" says "every reusable verb belongs to a noun" — `main` calls
`Daemon::start()` to bring up the supervision tree, and that's the
only verb. The actors do the work.

### 3.2 Supervision tree

```
main (root tokio runtime)
  ├── SemaActor          (root-spawned; long-lived; restart = abort process)
  └── ListenerActor      (root-spawned; references SemaActor)
        ├── ConnectionActor #1   (spawn_linked to Listener)
        ├── ConnectionActor #2   (spawn_linked to Listener)
        └── ConnectionActor #N
```

`SemaActor` is intentionally **not** a child of `ListenerActor` —
the storage layer outranks the I/O layer. If the listener dies
the sema state is fine; if sema dies we want the whole process
down because we have nothing to serve. Both are root-spawned and
the binary's `main` joins their handles; whichever exits first
triggers shutdown of the other.

### 3.3 Typed messages

Per-verb specificity (criome/ARCHITECTURE.md §2 Invariant D —
"perfect specificity"). The mailbox enum mirrors the dispatch
table in `dispatch.rs`; each variant carries its `RpcReplyPort`
typed to the verb's reply.

```rust
// src/sema_actor.rs
use ractor::{Actor, ActorRef, ActorProcessingErr, RpcReplyPort};
use signal::{
    AssertOperation, HandshakeRequest, QueryOperation,
    HandshakeReply, HandshakeRejectionReason, OutcomeMessage, Reply,
    Records,
};
use sema::Sema;

pub struct SemaActor;

pub enum SemaMessage {
    Handshake {
        request:    HandshakeRequest,
        reply_port: RpcReplyPort<HandshakeOutcome>,
    },
    Assert {
        operation:  AssertOperation,
        reply_port: RpcReplyPort<OutcomeMessage>,
    },
    Query {
        operation:  QueryOperation,
        reply_port: RpcReplyPort<Records>,
    },
    DeferredVerb {                       // M0: returns E0099 Diagnostic
        verb:       &'static str,
        milestone:  &'static str,
        reply_port: RpcReplyPort<OutcomeMessage>,
    },
}

pub enum HandshakeOutcome {
    Accepted(HandshakeReply),
    Rejected(HandshakeRejectionReason),
}

pub struct SemaArguments {
    pub sema_path: std::path::PathBuf,
}

pub struct SemaState {
    sema: Sema,
}
```

Note the messages do **not** carry a raw `Frame`. The frame is
decoded at the connection actor (where the I/O is) and the
relevant verb-specific subtree is sent to the sema actor; this is
the perfect-specificity invariant in action — no `HandleFrame`
god-message. The connection actor wraps the verb reply back into
a `Frame` after.

### 3.4 Skeleton: `SemaActor`

```rust
#[ractor::async_trait]
impl Actor for SemaActor {
    type Msg       = SemaMessage;
    type State     = SemaState;
    type Arguments = SemaArguments;

    async fn pre_start(
        &self,
        _myself:   ActorRef<Self::Msg>,
        arguments: SemaArguments,
    ) -> Result<Self::State, ActorProcessingErr> {
        let sema = Sema::open(&arguments.sema_path)?;
        Ok(SemaState { sema })
    }

    async fn handle(
        &self,
        _myself: ActorRef<Self::Msg>,
        message: SemaMessage,
        state:   &mut SemaState,
    ) -> Result<(), ActorProcessingErr> {
        match message {
            SemaMessage::Handshake { request, reply_port } => {
                let outcome = state.handshake(request);
                let _ = reply_port.send(outcome);
            }
            SemaMessage::Assert { operation, reply_port } => {
                let outcome = state.assert(operation);
                let _ = reply_port.send(outcome);
            }
            SemaMessage::Query { operation, reply_port } => {
                let records = state.query(operation);
                let _ = reply_port.send(records);
            }
            SemaMessage::DeferredVerb { verb, milestone, reply_port } => {
                let outcome = state.deferred_verb(verb, milestone);
                let _ = reply_port.send(outcome);
            }
        }
        Ok(())
    }
}
```

`SemaState::handshake` / `assert` / `query` / `deferred_verb` are
the existing methods on `Daemon` lifted onto `SemaState` with
trivial renames. Each is still sync — the actor handle just
serializes calls into them.

### 3.5 Skeleton: `ListenerActor`

```rust
// src/listener_actor.rs
pub struct ListenerActor;

pub struct ListenerArguments {
    pub socket_path: std::path::PathBuf,
    pub sema:        ActorRef<SemaMessage>,
}

pub struct ListenerState {
    listener: tokio::net::UnixListener,
    sema:     ActorRef<SemaMessage>,
}

pub enum ListenerMessage {
    Accept,                                 // self-tick
}

#[ractor::async_trait]
impl Actor for ListenerActor {
    type Msg       = ListenerMessage;
    type State     = ListenerState;
    type Arguments = ListenerArguments;

    async fn pre_start(
        &self,
        myself: ActorRef<Self::Msg>,
        arguments: ListenerArguments,
    ) -> Result<Self::State, ActorProcessingErr> {
        let _ = std::fs::remove_file(&arguments.socket_path);
        let listener = tokio::net::UnixListener::bind(&arguments.socket_path)?;
        ractor::cast!(myself, ListenerMessage::Accept)?;
        Ok(ListenerState { listener, sema: arguments.sema })
    }

    async fn handle(
        &self,
        myself: ActorRef<Self::Msg>,
        message: Self::Msg,
        state:   &mut ListenerState,
    ) -> Result<(), ActorProcessingErr> {
        match message {
            ListenerMessage::Accept => {
                let (stream, _) = state.listener.accept().await?;
                let arguments = ConnectionArguments {
                    stream,
                    sema: state.sema.clone(),
                };
                let _ = Actor::spawn_linked(
                    None,                 // anonymous; could be peer-id
                    ConnectionActor,
                    arguments,
                    myself.get_cell(),
                ).await?;
                ractor::cast!(myself, ListenerMessage::Accept)?;
            }
        }
        Ok(())
    }

    async fn handle_supervisor_evt(
        &self,
        _myself: ActorRef<Self::Msg>,
        event: ractor::SupervisionEvent,
        _state: &mut ListenerState,
    ) -> Result<(), ActorProcessingErr> {
        // Connection death is normal (client closed). Log on panic.
        if let ractor::SupervisionEvent::ActorFailed(actor, reason) = event {
            eprintln!("criome: connection {actor:?} failed: {reason}");
        }
        Ok(())
    }
}
```

Two things worth flagging in the listener:

1. **The accept loop is modeled as `cast(self, Accept)` re-arming
   itself.** This is the idiomatic ractor way to write an event
   loop without blocking the mailbox forever. Each `Accept` runs
   to completion, spawns the child, re-arms.
2. **Connection failures are `ActorFailed` events.** The listener
   logs and moves on — connections don't restart, they just die
   when the client disconnects.

### 3.6 Skeleton: `ConnectionActor`

```rust
// src/connection_actor.rs
pub struct ConnectionActor;

pub struct ConnectionArguments {
    pub stream: tokio::net::UnixStream,
    pub sema:   ActorRef<SemaMessage>,
}

pub struct ConnectionState {
    stream: tokio::net::UnixStream,
    sema:   ActorRef<SemaMessage>,
}

pub enum ConnectionMessage {
    ReadNext,
}

#[ractor::async_trait]
impl Actor for ConnectionActor {
    type Msg       = ConnectionMessage;
    type State     = ConnectionState;
    type Arguments = ConnectionArguments;

    async fn pre_start(
        &self,
        myself: ActorRef<Self::Msg>,
        arguments: ConnectionArguments,
    ) -> Result<Self::State, ActorProcessingErr> {
        ractor::cast!(myself, ConnectionMessage::ReadNext)?;
        Ok(ConnectionState {
            stream: arguments.stream,
            sema:   arguments.sema,
        })
    }

    async fn handle(
        &self,
        myself: ActorRef<Self::Msg>,
        _message: Self::Msg,
        state: &mut ConnectionState,
    ) -> Result<(), ActorProcessingErr> {
        match state.read_frame().await {
            Ok(frame) => {
                let reply_frame = state.dispatch_to_sema(frame).await?;
                state.write_frame(reply_frame).await?;
                ractor::cast!(myself, ConnectionMessage::ReadNext)?;
            }
            Err(error) if error.is_unexpected_eof() => {
                myself.stop(Some("client closed".into()));
            }
            Err(error) => return Err(error.into()),
        }
        Ok(())
    }
}
```

`ConnectionState::dispatch_to_sema` is where the `Frame` is
unpacked into a verb-specific message and `call`-ed against the
sema actor:

```rust
impl ConnectionState {
    async fn dispatch_to_sema(&self, frame: Frame) -> Result<Frame, Error> {
        let request = match frame.body {
            signal::Body::Request(r) => r,
            signal::Body::Reply(_)   => return Ok(self.protocol_error_frame(
                "E0098", "client sent Body::Reply where Body::Request expected",
            )),
        };

        let reply = match request {
            Request::Handshake(request) => {
                let outcome = self.sema
                    .call(|port| SemaMessage::Handshake { request, reply_port: port }, None)
                    .await??;
                match outcome {
                    HandshakeOutcome::Accepted(reply) => Reply::HandshakeAccepted(reply),
                    HandshakeOutcome::Rejected(reason) => Reply::HandshakeRejected(reason),
                }
            }
            Request::Assert(operation) => {
                let outcome = self.sema
                    .call(|port| SemaMessage::Assert { operation, reply_port: port }, None)
                    .await??;
                Reply::Outcome(outcome)
            }
            Request::Query(operation) => {
                let records = self.sema
                    .call(|port| SemaMessage::Query { operation, reply_port: port }, None)
                    .await??;
                Reply::Records(records)
            }
            Request::Mutate(_) | Request::Retract(_) | Request::AtomicBatch(_)
              | Request::Subscribe(_) | Request::Validate(_) => {
                let (verb, milestone) = deferred_for(&request);
                let outcome = self.sema
                    .call(|port| SemaMessage::DeferredVerb { verb, milestone, reply_port: port }, None)
                    .await??;
                Reply::Outcome(outcome)
            }
        };

        Ok(Frame { principal_hint: None, auth_proof: None, body: signal::Body::Reply(reply) })
    }
}
```

That `call` is the load-bearing seam — it's where the
"perfect-specificity" invariant lives. Every `Frame` that comes
in is decomposed before it crosses an actor boundary.

### 3.7 Startup sequence

```rust
// src/main.rs
#[tokio::main]
async fn main() -> Result<()> {
    let config = Config::from_env();

    let (sema_ref, sema_handle) = Actor::spawn(
        Some("sema".into()),
        SemaActor,
        SemaArguments { sema_path: config.sema_path },
    ).await?;

    let (listener_ref, listener_handle) = Actor::spawn(
        Some("listener".into()),
        ListenerActor,
        ListenerArguments {
            socket_path: config.socket_path,
            sema: sema_ref.clone(),
        },
    ).await?;

    eprintln!("criome-daemon: ready");

    // Whichever exits first triggers full shutdown of the other.
    tokio::select! {
        _ = sema_handle     => listener_ref.stop(None),
        _ = listener_handle => sema_ref.stop(None),
    }

    Ok(())
}
```

### 3.8 Graceful shutdown

`SIGTERM` → catch in `main` via `tokio::signal::unix` → `stop(None)`
on both root actors → ractor drains user-message queue, runs
`post_stop`, joins. Connections die when their parent listener
stops them. No `Arc<AtomicBool>`-style ad-hoc shutdown signaling.

---

## 4. Proposed nexus-daemon as ractor

### 4.1 Actor inventory

| name              | role                                  | state owned                       |
|-------------------|---------------------------------------|-----------------------------------|
| `ListenerActor`   | UDS accept loop                       | `UnixListener`, criome-socket-path|
| `ConnectionActor` | per-client text shuttle               | `UnixStream`, `CriomeLink` (in-flight) |

Note **no `CriomeLink` actor**. The link is single-owner, one
request/reply at a time, with FIFO pairing — there's no
concurrency to model. It stays a plain async type living inside
`ConnectionState`. This is exactly the case style.md §Actors
calls out: "Use actors for components, not for chores. A function
that awaits an HTTP call is a method, not an actor."

### 4.2 Supervision tree

```
main
  └── ListenerActor          (root-spawned)
        ├── ConnectionActor #1   (spawn_linked; owns its own CriomeLink)
        ├── ConnectionActor #2
        └── ConnectionActor #N
```

The shape is identical to criome's listener+connection layer; the
only difference is the connection actor doesn't have a Sema-actor
peer to call — it dials criome directly via `CriomeLink::open`.

### 4.3 Typed messages

```rust
// nexus/src/listener_actor.rs
pub struct ListenerActor;

pub struct ListenerArguments {
    pub listen_path:        std::path::PathBuf,
    pub criome_socket_path: std::path::PathBuf,
}

pub struct ListenerState {
    listener:           tokio::net::UnixListener,
    criome_socket_path: std::path::PathBuf,
}

pub enum ListenerMessage {
    Accept,
}
```

```rust
// nexus/src/connection_actor.rs
pub struct ConnectionActor;

pub struct ConnectionArguments {
    pub client:             tokio::net::UnixStream,
    pub criome_socket_path: std::path::PathBuf,
}

pub struct ConnectionState {
    client:             tokio::net::UnixStream,
    criome_socket_path: std::path::PathBuf,
    criome:             Option<CriomeLink>,  // lazily opened on first request
}

pub enum ConnectionMessage {
    Run,    // single shuttle pass; M0 is one-shot
}
```

The `Run` message is a single tick — read text-to-EOF, do the
shuttle, write, stop self. M0 is one-shot (per
`connection.rs` doc), so the actor's lifecycle is essentially
"start → one Run → stop." It looks vestigial as an actor at this
stage, and it would be — except:

1. **M1+ adds streaming framing.** When the connection becomes a
   long-lived loop (read-request → forward → write-reply →
   repeat), the actor structure already exists.
2. **M2+ adds Subscribe.** The connection becomes bidirectional —
   it has to receive subscription updates from the criome link
   and forward them to the client. That maps cleanly to a second
   message variant on `ConnectionMessage` (e.g.
   `SubscriptionUpdate(Reply)`) that the connection actor
   forwards.
3. **Supervision is real even at M0.** A panicking shuttle gets
   reported up to the listener as `ActorFailed`, instead of
   silently disappearing into a detached `tokio::spawn`.

### 4.4 Skeleton: `ConnectionActor`

```rust
#[ractor::async_trait]
impl Actor for ConnectionActor {
    type Msg       = ConnectionMessage;
    type State     = ConnectionState;
    type Arguments = ConnectionArguments;

    async fn pre_start(
        &self,
        myself: ActorRef<Self::Msg>,
        arguments: ConnectionArguments,
    ) -> Result<Self::State, ActorProcessingErr> {
        ractor::cast!(myself, ConnectionMessage::Run)?;
        Ok(ConnectionState {
            client:             arguments.client,
            criome_socket_path: arguments.criome_socket_path,
            criome:             None,
        })
    }

    async fn handle(
        &self,
        myself: ActorRef<Self::Msg>,
        _message: ConnectionMessage,
        state: &mut ConnectionState,
    ) -> Result<(), ActorProcessingErr> {
        if let Err(error) = state.shuttle().await {
            eprintln!("nexus: connection error: {error}");
        }
        myself.stop(None);
        Ok(())
    }
}
```

`ConnectionState::shuttle` is the existing
`Connection::shuttle` body lifted onto the state struct — same
control flow, same parser, same renderer, same `CriomeLink::open
+ send` calls. The actor wrapper adds nothing to the shuttle's
internals; it adds a typed lifecycle around it.

### 4.5 Subscription support (M2+) — note for design only

When `Subscribe` lands, the criome reply side becomes
streaming — a single subscribe request kicks off many replies
over time. The clean shape:

- `CriomeLink` gains an `into_subscription_stream(self) -> impl Stream<Reply>`
  method that converts the link's read half into a stream after a
  Subscribe is sent.
- The connection actor `tokio::spawn`s a task that polls the
  stream and `cast`s `ConnectionMessage::SubscriptionReply(reply)`
  back to itself for each one.
- The handler renders the reply incrementally to the client and
  flushes.

This maps cleanly onto the actor model: the connection actor's
mailbox is the serialization point, and every subscription update
goes through `handle` like any other message. No `Mutex` needed.

---

## 5. What stays sync (one-shot binaries)

Three companion binaries exist in the workspace and **none of
them should become actors**:

- `criome-handle-frame` (`criome/src/bin/handle_frame.rs`) —
  reads one frame on stdin, calls `Daemon::handle_frame` once,
  writes the reply on stdout, exits. No concurrent state.
- `nexus-parse` (`nexus/src/bin/parse.rs`) — text → AST → text.
- `nexus-render` (`nexus/src/bin/render.rs`) — wire reply → text.

Per style.md §Actors: *"A function that awaits an HTTP call is a
method, not an actor. An actor exists because the *concept* it
models warrants its own state and protocol."* These binaries are
the canonical case for the sync side of that boundary — they're
pipeline filters, not concurrent components, and ractor would be
an actively wrong tool. They keep `fn main` and call into the
library's pure types directly.

The fact that these binaries exist (per reports/100 §5) is
**load-bearing for the migration** — they're how the per-verb
logic stays testable as a pure function even after the daemon
becomes an actor tree. The actor's `handle` body can call the
same `SemaState::assert` etc. that `criome-handle-frame` calls,
and we can keep proving the verbs sync-correct in isolation.

---

## 6. Tradeoffs

### 6.1 What ractor buys

1. **Typed message protocol per actor.** Each verb is a variant;
   the compiler refuses to send the wrong shape. This is the
   perfect-specificity invariant enforced at the type level
   instead of by convention.
2. **Owned state, no `Arc<Mutex<T>>`.** `Sema` lives inside
   `SemaState`, full stop. The "is this `Arc<Sema>` cloned in
   the right places?" question disappears.
3. **Supervision events make connection failures visible.** Today
   a panicking detached `tokio::spawn` task is logged via
   `eprintln!` and forgotten. With ractor the listener's
   `handle_supervisor_evt` sees every `ActorFailed` and can
   decide what to do (count, restart, escalate).
4. **Graceful shutdown is built-in.** `stop()` flows from the
   root through the tree; no ad-hoc shutdown channels.
5. **The shape extends to M2+ Subscribe naturally.** Streaming
   replies become extra message variants instead of new
   concurrency primitives.
6. **The tooling assumption matches the codebase direction.**
   `ractor = "0.15"` is in `Cargo.toml` already; using it closes
   the unused-dep loop and aligns with style.md §Actors.

### 6.2 What ractor costs

1. **More code.** Each daemon grows by roughly one file per
   actor: `sema_actor.rs`, `listener_actor.rs`, `connection_actor.rs`
   in criome (plus message types). Estimate +200 LoC for criome,
   +150 for nexus, before counting deletions.
2. **Less obvious control flow.** A `cast(self, Accept)` self-tick
   is idiomatic ractor but reads less directly than `loop {
   listener.accept().await?; ... }`. New readers will have to
   learn the pattern.
3. **Per-message overhead.** A frame round-trip in criome
   currently is one sync `handle_frame` call on `Arc<Daemon>`.
   With actors it's: connection decodes frame → builds verb-
   specific message + `RpcReplyPort` → mailbox enqueue →
   sema actor dequeues → runs verb → `reply_port.send` →
   connection awaits → encodes reply. **For the M0 demo this is
   imperceptible** (we're talking microseconds of mailbox
   crossing vs. a redb txn at hundreds of microseconds), but it
   is real overhead.
4. **Serialization on the sema mailbox.** Today, two connections
   asserting concurrently both call into redb at the same time
   and redb's own locking serializes them at the storage layer.
   With a single `SemaActor`, the mailbox serializes them
   *before* redb sees them. This is a behavior change.
   - For *writes*, redb already serializes — no real change.
   - For *reads (queries)*, this is a regression: today queries
     can run concurrently against redb's MVCC; with one actor
     they queue. Mitigation: hold one `SemaActor` for writes and
     a `ReadOnlySemaActor` (or pool of them) for queries. **This
     is an open question for M2+; not worth solving in M0.**
5. **Debugging stack traces are deeper.** A panic inside `handle`
   shows the ractor dispatch frames before user code. Tractable,
   but slightly more machinery in every backtrace.

### 6.3 Where ractor would be wrong

The sync one-shot binaries (§5). Plus anywhere else that's a
pure function — `Parser`, `Renderer`, the validator pipeline,
the dispatch table itself. Actors are for components; methods
are for verbs. Don't introduce an actor where the sync method
already does the job.

### 6.4 Risk: cross-actor `call` deadlocks

A classic ractor footgun: actor A `call`s actor B, which during
the handler `call`s actor A back. Both mailboxes block on each
other; deadlock.

In our shape this **cannot** happen because the call graph is
strictly downward: connection → sema (or connection → criome-link
which is not an actor). Sema has no upward `call` to make. We
should keep this invariant explicit in a comment at the top of
`sema_actor.rs`: *"SemaActor never calls any other actor; its
handlers are sync over Sema."*

---

## 7. Migration plan

### 7.1 Sequence

**Phase 1: criome-daemon** — single-component-to-lift, lowest
risk.

1. Add `sema_actor.rs` + `SemaMessage` enum + the lifted
   `SemaState::{handshake, assert, query, deferred_verb}` methods.
   Delete the `Daemon` struct's `Arc<Sema>` field; the verb
   handlers move onto `SemaState` unchanged.
2. Add `connection_actor.rs` + `ConnectionMessage` + the
   `dispatch_to_sema` body. The frame-decode and verb-decompose
   logic moves here from the old `dispatch.rs` — `dispatch.rs`
   itself disappears (or shrinks to a one-liner that names the
   verb-message mapping).
3. Add `listener_actor.rs` + `ListenerMessage`. Delete `uds.rs`
   (its body is now split between `listener_actor.rs` for the
   accept loop and `connection_actor.rs` for the per-connection
   read/write — same code, different home).
4. Rewrite `main.rs` to spawn the two root actors and join.
5. **`criome-handle-frame` does not change** — it still calls
   the pure `SemaState::*` verbs.

**Phase 2: nexus-daemon** — once criome's pattern is settled.

6. Add `listener_actor.rs` + `connection_actor.rs` for nexus.
7. The existing `Connection::shuttle` body moves wholesale onto
   `ConnectionState::shuttle` — same code.
8. `criome_link.rs` does not change. It stays a plain async
   type owned by `ConnectionState`.

**Phase 3 (deferred to M1+):** read-only sema actor pool for
query concurrency (§6.2 #4); subscription support (§4.5).

Each phase is a single PR; each PR keeps `nix flake check` green
end-to-end, including the integration test in
`mentci/checks/integration.nix`.

### 7.2 What tests change

- **Unit tests for `Daemon::handle_frame`** become unit tests for
  `SemaState::{handshake, assert, query}`. They stay sync. They
  test the same behavior; the test file rename is the diff.
- **`criome-handle-frame` integration tests** do not change —
  the binary's contract (one frame in, one frame out) is
  preserved.
- **`nexus-parse` / `nexus-render` tests** do not change.
- **`mentci/checks/integration.nix`** does not change. It pokes
  the daemons from outside via `nexus-cli` and watches stdout;
  the inside is opaque to it. This is the load-bearing test for
  the migration's correctness — if the integration check
  passes after each phase, the migration is sound.

### 7.3 Rollback

Each phase is a single git commit with a clear before/after. If
phase 1 destabilizes anything, `git revert` restores the prior
shape without affecting nexus. If phase 2 destabilizes nexus,
revert nexus' commit; phase-1 criome stays as the new shape.

The actor migration is **not a rewrite** — it's a re-housing of
the existing verb implementations. The lojix daemon (when it
lands) inherits the same shape from day one.

---

## 8. Open questions for Li

1. **Single sema actor vs. read-pool.** §6.2 #4: one actor
   serializes queries, which is a regression vs. today's
   concurrent redb reads. Acceptable for M0 (we have one client
   at a time in the demo), but worth flagging for M2+. Want to
   defer? Or design read-pool now?

2. **Connection actor naming inside criome and nexus.**
   `ConnectionActor` exists in both crates. Same name, same
   shape, different inner state. Currently I have them as
   separate types in each crate. Worth factoring into a shared
   `signal` / `nexus` helper? My instinct: no — the duplication
   is honest and the inner shapes diverge once nexus gets
   subscription support. But flagging.

3. **Should `Daemon` (the noun) survive?** Currently in both
   crates `Daemon` is a struct with one verb (`run` / `start`).
   Post-migration it'd shrink to just constructing the actor
   tree. Options: (a) keep `Daemon::start()` as the façade
   `main` calls; (b) inline into `main`. Style.md says "every
   reusable verb belongs to a noun" — `start` is a verb, so (a)
   feels right, but `Daemon` becomes very thin. Preference?

4. **Restart policy on connection panic.** Current proposal:
   listener logs `ActorFailed` and moves on, no restart. (A
   panicking shuttle means we couldn't write the reply anyway;
   the client will see EOF.) Alternative: restart-with-backoff,
   but that requires reconstructing the `UnixStream` which is
   gone. I think "log and forget" is right; confirm.

5. **Do we put the actors in their own files (`sema_actor.rs` /
   `listener_actor.rs` / `connection_actor.rs`) or inline them
   in existing files?** Style.md §"One concern per file" says
   one. The `_actor` suffix feels redundant though — `sema.rs`
   would be cleaner if we hadn't named the storage crate `sema`
   already. Open to a better name (`storage.rs`?
   `sema_handler.rs`?). My current preference: `sema_actor.rs`,
   `listener.rs` (replaces `uds.rs`), `connection.rs` (new).

6. **Timing of phase 1.** This migration is one PR's worth of
   work — call it half a day to a day for criome, similar for
   nexus. M0 is currently shipping (per reports/100); the
   integration test is green; sema-vbf is the active branch.
   Question: do we land the migration **before** the lojix
   daemon arrives (so lojix is born actor-shaped) or **after**
   M0 demo (so we don't perturb shipping work)? I'd vote
   "before lojix is born" — every component we let calcify in
   the old shape is a future migration. But your call.

7. **`Frame` unwrap location.** In the proposal, the connection
   actor decodes the frame and dispatches verb-specifically
   to sema. Alternative: send the whole `Frame` to a generic
   `SemaMessage::HandleFrame { frame, reply_port }`. The latter
   is closer to today's `Daemon::handle_frame` and is one less
   place to change. But it violates perfect-specificity (a god
   message). I went with the verb-specific shape. Confirm or
   override.

---

## Appendix A: file map (proposed)

```
criome/src/
├── lib.rs
├── error.rs
├── kinds.rs                    (unchanged)
├── handshake.rs                (verb handlers — methods on SemaState now)
├── assert.rs                   (ditto)
├── query.rs                    (ditto)
├── validator/                  (unchanged)
├── sema_actor.rs               NEW — SemaActor + SemaMessage + SemaState
├── listener.rs                 RENAMED from uds.rs — ListenerActor + ListenerMessage
├── connection.rs               NEW — ConnectionActor + ConnectionMessage + dispatch_to_sema
├── main.rs                     REWRITTEN — spawns root actors
└── bin/handle_frame.rs         (unchanged — calls SemaState verbs directly)

nexus/src/
├── lib.rs
├── error.rs
├── parser.rs                   (unchanged)
├── renderer.rs                 (unchanged)
├── criome_link.rs              (unchanged)
├── listener.rs                 NEW — ListenerActor + ListenerMessage
├── connection.rs               REWRITTEN — ConnectionActor + ConnectionMessage; shuttle body lifted onto ConnectionState
├── daemon.rs                   SHRINKS or REMOVED — see open question 3
├── main.rs                     REWRITTEN — spawns root actor
└── bin/{parse,render}.rs       (unchanged)
```

Net file deltas: criome +2 new files, 1 rename, 0 deletes; nexus
+1 new file, 1 rewrite, possible 1 delete. Roughly +400 LoC
gross / +200 LoC net (after deleting old uds.rs and Daemon
plumbing).

---

## Appendix B: things deliberately NOT proposed

- **No actor for `Parser`.** Parser is sync, single-owner,
  no concurrent state. It stays as it is.
- **No actor for `Renderer`.** Same.
- **No actor for `CriomeLink`.** Same. (The link is held inside
  ConnectionState; one in-flight request at a time is exactly
  what its API expresses.)
- **No global "registry" of named actors.** Ractor has a
  registry feature; we don't need it. Actor refs flow through
  `Arguments`.
- **No `ractor_cluster` integration.** Distributed actors are
  out of scope for M0/M1. Single-process supervision only.
- **No retrofitting `lojix-daemon` in this migration.** It
  doesn't exist as a daemon yet. When it lands, it's born
  ractor-shaped — same `ListenerActor + ConnectionActor`
  pattern, with a `LojixActor` peer the way criome has
  `SemaActor`.
