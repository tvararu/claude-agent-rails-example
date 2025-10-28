# Technical Spike: Claude Agent SDK (TypeScript)

## Overview

Integration using `@anthropic-ai/claude-agent-sdk` with Node.js service communicating to Rails.

**Route:** `/agent/claude-agent-sdk-typescript`

## Prerequisites

- Node.js environment for running agent service
- `@anthropic-ai/claude-agent-sdk` npm package
- Express or similar for HTTP server
- Anthropic API key configured

## Architecture

```
Browser (WebSocket)
   ↓
Rails ActionCable Channel
   ↓ HTTP POST/SSE
Node.js Express Service
   ↓
@anthropic-ai/claude-agent-sdk
   ↓
Anthropic API
```

## How It Should Work

### Service Communication

Rails and Node communicate via HTTP:
- Rails sends prompt via POST request
- Node responds with Server-Sent Events (SSE) stream
- Rails broadcasts SSE events to ActionCable
- Browser receives real-time updates

Alternative: Node could expose WebSocket directly, bypassing ActionCable.

### User Flow

1. User navigates to `/agent/claude-agent-sdk-typescript`
2. Browser opens WebSocket to Rails ActionCable
3. User types message in chat interface
4. ActionCable channel receives message
5. Rails makes HTTP POST to Node service (localhost:3001)
6. Node service uses TypeScript SDK to query agent
7. Agent responses stream via SSE back to Rails
8. Rails broadcasts each SSE event to ActionCable
9. Browser displays responses in real-time

### Agent Capabilities

The agent should be able to:
- Read files from the Rails application directory (shared volume/path)
- Call back to Rails API endpoints for database operations
- Use custom tools defined in Node.js
- Execute Node.js code directly

### Custom Tool Integration

Two approaches for Rails-specific tools:

**Approach 1: Rails API Endpoint**
- Node tool calls Rails HTTP endpoint
- Endpoint: `GET /api/schema`
- Returns JSON with database schema
- Simple but requires Rails API

**Approach 2: Direct Database Access**
- Node connects to PostgreSQL directly
- Uses connection string from Rails
- Bypasses Rails entirely
- More complex, duplicates connection logic

**Preferred:** Approach 1 - use Rails API endpoints

### Message Flow

**User message:**
```
"What tables are in the database?"
```

**Expected flow:**
1. Browser → ActionCable: "What tables are in the database?"
2. Rails → Node: POST /prompt with message
3. Node SDK processes prompt
4. Agent decides to use `check_schema` tool
5. Node tool executes: `fetch('http://localhost:3000/api/schema')`
6. Rails API returns: `{tables: ['users', 'posts', ...], count: 5}`
7. Agent receives tool result
8. Agent formulates response
9. Node → Rails: SSE stream with response chunks
10. Rails → ActionCable: broadcast each chunk
11. Browser: displays response progressively

### Process Management

Two approaches:

**Development:**
- Use `Procfile.dev` with foreman/overmind
- Start both Rails and Node together
- Single command: `foreman start`

**Production:**
- Run Node as separate container
- Use Kamal accessories or similar
- Health checks on both services
- Shared volume for file access

### Cross-Service Communication

**Rails needs to know:**
- Node service URL (environment variable)
- Health check endpoint
- Whether service is running

**Node needs to know:**
- Rails root directory path
- Rails API base URL for tools
- API authentication token (if required)

## Testing Acceptance Criteria

### Basic Functionality

1. **Service startup**
   - Start both Rails and Node services
   - Node service health check returns 200
   - Rails can reach Node at configured URL
   - No startup errors in either log

2. **Visit route**
   - Navigate to `http://localhost:3000/agent/claude-agent-sdk-typescript`
   - Page loads with chat interface
   - WebSocket connection establishes
   - No errors in browser console

3. **Simple conversation**
   - Type: "Hello, can you see me?"
   - Receive response within 3 seconds
   - Response appears progressively (streaming works)

4. **File access**
   - Type: "What files are in the app/models directory?"
   - Agent lists model files
   - File names match actual Rails filesystem

5. **Rails API tool execution**
   - Type: "What tables are in the database?"
   - Agent calls `check_schema` tool
   - Tool makes HTTP request to Rails API
   - Rails logs show API call
   - Response includes actual table names
   - Table count is accurate

6. **Multi-turn conversation**
   - Type: "What tables are in the database?"
   - Receive response with table list
   - Type: "How many records are in the users table?"
   - Agent maintains context
   - Response references users table specifically

7. **Error handling - Node down**
   - Stop Node service
   - Type a message
   - Rails returns error: "Agent service unavailable"
   - Error displayed gracefully in UI

8. **Error handling - API rate limit**
   - Trigger rate limit (send many requests quickly)
   - Agent returns appropriate error message
   - System recovers when limit resets

### Process Management

9. **Concurrent sessions**
   - Open two browser tabs
   - Send different messages simultaneously
   - Both sessions receive correct responses
   - No cross-contamination

10. **Graceful shutdown**
    - Stop foreman
    - Both services terminate
    - No orphaned processes
    - Connections close cleanly

### Cross-Service Integration

11. **File access across services**
    - Rails in `/app`, Node sees same directory
    - Type: "Read config/database.yml"
    - Agent reads correct file
    - Content matches actual file

12. **Rails API authentication**
    - Rails API requires auth token
    - Node includes token in requests
    - Tool calls succeed
    - Unauthorized requests fail

## Open Questions

1. **Tool definition**: How are tools defined in the TypeScript SDK?
   - As plain JavaScript functions?
   - With schema/type definitions?
   - Registered globally or per-request?

2. **Streaming implementation**:
   - Does SDK support streaming natively?
   - Is it via async iterators?
   - How do we differentiate message types in stream?

3. **Session management**:
   - How are conversations tracked?
   - Is there a session ID concept?
   - Can we restore previous conversations?

4. **Working directory**:
   - How do we set agent's working directory?
   - Can we use absolute paths?
   - What if Rails and Node are in different containers?

5. **Deployment**:
   - Single container with both Rails & Node?
   - Separate containers with shared volume?
   - How to handle file access across containers?

6. **Error propagation**:
   - How do SDK errors surface?
   - Can we catch and handle specific error types?
   - What about network errors between services?

## Success Criteria

The spike is successful if we can:
- Send message from Rails and receive response from Node
- Stream responses in real-time via SSE
- Execute custom tool that calls Rails API
- Understand process management requirements
- Validate approach works for production deployment
- Document SDK capabilities and Rails integration patterns
