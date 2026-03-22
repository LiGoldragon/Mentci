<!-- SUPERSEDED: This document is now a read-only projection of samskara
     relations. The authoritative source is the `rule` relation in samskara's
     world.db. To query: ?[id, body, rationale] := *rule{id, body, rationale,
     microtheory: "mcp"} -->

# MCP Patterns

Model Context Protocol server structure for Criome components. Each
MCP server is the external interface to a component's actor — tools
map to messages the actor handles.

---

## Server Struct

```rust
#[derive(Clone)]
pub struct Server {
    client: Arc<T>,           // the component's owned state
    tool_router: ToolRouter<Self>,
}

impl Server {
    pub fn new(client: Arc<T>) -> Self {
        Self {
            client,
            tool_router: Self::tool_router(),
        }
    }
}
```

The server wraps an `Arc<T>` of the component's core type. The
`ToolRouter` is self-referencing via `Self::tool_router()`.

---

## ServerHandler

```rust
#[tool_handler(router = self.tool_router)]
impl ServerHandler for Server {
    fn get_info(&self) -> ServerInfo {
        ServerInfo {
            instructions: Some("...".into()),
            capabilities: ServerCapabilities::builder().enable_tools().build(),
            ..Default::default()
        }
    }
}
```

---

## Tool Definitions

```rust
#[tool_router]
impl Server {
    #[tool(description = "What this tool does")]
    async fn tool_name(
        &self,
        Parameters(params): Parameters<ToolParams>,
    ) -> String {
        // ...
    }
}
```

**Rules:**
- Tools return `String` — JSON on success, `{"error": "..."}` on failure
- Parameter types derive `serde::Deserialize` + `schemars::JsonSchema`
- Each tool is `async fn`
- CPU-bound operations use `tokio::task::spawn_blocking`

---

## Parameter Types

```rust
#[derive(Debug, serde::Deserialize, schemars::JsonSchema)]
pub struct SearchParams {
    /// Description shown to the LLM
    pub query: String,
    #[serde(default)]
    pub page: Option<u32>,
}
```

Use `#[schemars(description = "...")]` or doc comments for tool
parameter descriptions. Use `#[serde(default)]` for optional fields.

---

## Stdio Protocol

MCP uses JSON-RPC over stdio. Stdout is reserved for the protocol.
All logging goes to stderr via tracing:

```rust
tracing_subscriber::fmt()
    .with_writer(std::io::stderr)
    .with_ansi(false)
    .init();
```

---

## Server Startup

```rust
let service = rmcp::ServiceExt::serve(server, rmcp::transport::stdio()).await?;
service.waiting().await?;
```

The binary's `main.rs` is an orchestration shell — it reads config,
creates the component's core state, wraps it in the MCP server, and
starts the stdio transport. No reusable logic in `main.rs`.

---

## Dependencies

```toml
rmcp = { version = "0.16", features = ["server", "transport-io", "macros"] }
schemars = "1.0"
```

Client features (`"client"`) are for dev-dependencies only (testing).

---

## Testing

1. **Unit tests** with fixture data (offline, `#[cfg(test)]`)
2. **Live integration tests** (`#[ignore]`, requires network + credentials)
3. **MCP client test** — start the server via the wrapper, verify tools
   are discoverable and return valid responses

Ship after step 3, not step 1. A server that passes unit tests but
fails when an MCP client connects is not tested.
