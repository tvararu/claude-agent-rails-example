# Technical Spike: Agent Client Protocol (ACP)

## Overview

Integration using `@zed-industries/claude-code-acp` via the Agent Client Protocol standard.

**Route:** `/agent/claude-code-acp`

## Prerequisites

- `@zed-industries/claude-code-acp` npm package installed globally
- Anthropic API key configured
- Understanding of JSON-RPC 2.0 protocol

## Architecture

```
Browser (WebSocket)
   ↓
Rails ActionCable Channel
   ↓
Ruby ACP Client (JSON-RPC over stdio)
   ↓ spawns subprocess
claude-code-acp process (Node.js)
   ↓
Anthropic API
```

## How It Should Work

### Protocol Communication

ACP uses JSON-RPC 2.0 over stdin/stdout:
- Rails spawns `claude-code-acp` as subprocess
- Sends JSON-RPC requests to stdin
- Reads JSON-RPC responses/notifications from stdout
- Bidirectional: both client and agent can initiate requests

### User Flow

1. User navigates to `/agent/claude-code-acp`
2. Browser opens WebSocket to Rails ActionCable
3. User types message in chat interface
4. ActionCable channel receives message
5. Rails service spawns (or reuses) `claude-code-acp` process
6. Service sends `initialize` request
7. Service creates session via `session/create`
8. Service submits prompt via `session/submit`
9. Agent streams `session/update` notifications
10. Rails broadcasts each update to ActionCable
11. Browser displays responses in real-time

### ACP Protocol Flow

```
Client → Agent: initialize (protocol version, capabilities)
Agent → Client: initialization response (agent capabilities)
Client → Agent: session/create
Agent → Client: {sessionId: "..."}
Client → Agent: session/submit (prompt content)
Agent → Client: session/update (streaming notifications)
Agent → Client: session/update (plan updates)
Agent → Client: session/update (tool calls)
Client → Agent: session/approve_tool_call (if permission needed)
Agent → Client: session/update (final response)
```

### Agent Capabilities

The agent can:
- Read files via `fs/read_text_file` (ACP built-in)
- Write files via `fs/write_text_file` (ACP built-in)
- Execute terminal commands (via ACP terminal protocol)
- Call custom tools (two approaches - see below)

### Custom Tool Integration

**ACP provides THREE ways to offer custom tools:**

#### Approach 1: ACP Built-in Tool Calls

ACP defines its own tool system with 9 tool kinds:
- `read`, `edit`, `delete`, `move`, `search`, `execute`, `think`, `fetch`, `other`

Agents report tool calls via `session/update` notifications. The client can:
- Observe tool execution
- Request permission before dangerous operations
- Provide custom tool implementations

**Method:** Implement tools in Ruby, intercept tool call notifications, execute, return results.

#### Approach 2: MCP Server Integration

Pass MCP server configurations to the agent:
- Agent connects to MCP servers directly
- MCP servers can be written in any language
- Standard MCP protocol for tool discovery/execution

**Method:** Run separate MCP server process (e.g., Ruby script), configure `claude-code-acp` to connect to it.

#### Approach 3: Client-Side Tool Proxying

Client can expose tools via a lightweight proxy:
- Client receives tool call notification
- Client executes Ruby code
- Client sends results back via JSON-RPC

**Method:** Similar to Approach 1 but more explicit.

**Recommendation for spike:** Use Approach 1 (ACP built-in) - simplest integration.

### Message Flow Example

**User message:**
```
"What tables are in the database?"
```

**Expected JSON-RPC flow:**

```json
// Client → Agent
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "session/submit",
  "params": {
    "sessionId": "abc123",
    "content": [{"type": "text", "text": "What tables are in the database?"}]
  }
}

// Agent → Client (notification)
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "abc123",
    "type": "tool_call",
    "toolCallId": "tool_1",
    "title": "Check database schema",
    "kind": "read",
    "status": "pending"
  }
}

// Client → Agent (approve or execute locally)
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "session/approve_tool_call",
  "params": {
    "sessionId": "abc123",
    "toolCallId": "tool_1",
    "result": {
      "tables": ["users", "posts", "comments"],
      "count": 3
    }
  }
}

// Agent → Client (final response)
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "abc123",
    "type": "message",
    "content": [{"type": "text", "text": "The database has 3 tables: users, posts, and comments."}]
  }
}
```

### Process Management

**Single long-running process:**
- Spawn once on first request
- Keep alive for subsequent requests
- Track sessions via sessionId
- Terminate on Rails shutdown

**Or per-request spawning:**
- Spawn for each conversation
- Simpler but slower
- No session state to manage

## Testing Acceptance Criteria

### Basic Functionality

1. **Visit route**
   - Navigate to `http://localhost:3000/agent/claude-code-acp`
   - Page loads with chat interface
   - No errors in browser console or Rails logs

2. **Protocol initialization**
   - Service spawns `claude-code-acp` subprocess
   - `initialize` request succeeds
   - Agent reports capabilities
   - Rails logs show JSON-RPC exchanges

3. **Simple conversation**
   - Type: "Hello, can you see me?"
   - `session/create` succeeds
   - `session/submit` sends prompt
   - Receive `session/update` notifications
   - Response displays within 3 seconds

4. **ACP filesystem access**
   - Type: "Read config/routes.rb"
   - Agent uses `fs/read_text_file`
   - File content returned accurately
   - Matches actual file on disk

5. **Custom tool via ACP**
   - Type: "What tables are in the database?"
   - Agent sends `session/update` with tool call
   - Rails intercepts notification
   - Rails executes `ActiveRecord::Base.connection.tables`
   - Rails sends result via `session/approve_tool_call`
   - Agent responds with table list
   - Table names are accurate

6. **Streaming updates**
   - Type: "List all models and their purposes"
   - Multiple `session/update` notifications arrive
   - UI updates progressively
   - Final response is complete

7. **Multi-turn conversation**
   - Type: "What tables are in the database?"
   - Receive response
   - Type: "How many columns does users have?"
   - Agent maintains session context
   - Response references users table

8. **Plan tracking**
   - Type: "Create a new migration for adding email to users"
   - Receive `session/update` with plan items
   - Plan shows: read schema, generate migration, write file
   - Each plan item updates status (pending → in_progress → completed)
   - UI displays plan progress

### Error Handling

9. **Process crash recovery**
   - Kill `claude-code-acp` process manually
   - Send message
   - Service detects crash
   - Spawns new process
   - Conversation continues (or graceful error)

10. **Invalid JSON-RPC**
    - Agent sends malformed JSON
    - Rails parses error gracefully
    - Error logged but doesn't crash
    - User sees: "Agent communication error"

11. **Permission denial**
    - Agent requests dangerous operation
    - Rails denies via `session/deny_tool_call`
    - Agent acknowledges denial
    - Conversation continues without executing tool

### Process Management

12. **Subprocess lifecycle**
    - Start Rails server
    - No `claude-code-acp` process running
    - First request spawns process
    - Subsequent requests reuse process
    - Stop Rails server
    - Subprocess terminates cleanly

13. **Concurrent sessions**
    - Open two browser tabs
    - Each gets unique sessionId
    - Send different messages
    - Responses don't cross-contaminate
    - Both sessions work independently

## Open Questions

1. **Tool result format**: What's the exact schema for `session/approve_tool_call` results?
   - Is it free-form JSON?
   - Does it need specific structure?
   - How are errors communicated?

2. **Permission system**: When does the agent ask for permission?
   - Is it automatic for certain tool kinds?
   - Can we configure permission rules?
   - How do we approve/deny programmatically?

3. **Session persistence**: Can we save and restore sessions?
   - Is there a session export format?
   - Can we resume interrupted conversations?
   - Where is session state stored?

4. **MCP integration**: If we use MCP for custom tools:
   - How do we configure MCP servers?
   - Do we pass config in `initialize`?
   - Can MCP servers be in Ruby?

5. **Error recovery**: How should we handle:
   - Agent timeout (no response for 30s)?
   - Malformed JSON-RPC from agent?
   - API rate limits?
   - Network failures?

6. **Protocol versioning**: The initialize includes `protocolVersion`:
   - What happens with version mismatch?
   - Can we negotiate features?
   - How do we know what features are available?

## Success Criteria

The spike is successful if we can:
- Establish JSON-RPC communication with agent
- Send prompts and receive streaming updates
- Use ACP built-in filesystem operations
- Implement at least one custom tool (database schema check)
- Understand the difference between ACP tools, MCP tools, and filesystem ops
- Document the Ruby implementation pattern for ACP clients
- Validate that the protocol is practical for production use
- Determine if ACP's standardization benefits outweigh implementation complexity

## Key Research Goals

1. **Is a pure Ruby ACP client feasible?**
   - Or do we need existing library?
   - How much protocol implementation is needed?

2. **MCP vs ACP tools: which is better for Rails integration?**
   - MCP = separate server process
   - ACP = inline tool execution
   - Which is simpler for our use case?

3. **Can we avoid Node entirely?**
   - Or is `claude-code-acp` the only practical agent?
   - Are there ACP agents in other languages?
