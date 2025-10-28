# Spike Results: Claude Agent SDK (TypeScript)

**Status:** ✅ **SUCCESS**

## Summary

The `@anthropic-ai/claude-agent-sdk` TypeScript package (v0.1.28) successfully integrates with Rails via a Node.js service bridge. The architecture uses HTTP POST/SSE for communication between Rails and Node, with real-time streaming via ActionCable.

## What Works

✅ **Multi-Service Architecture**
- Node.js Express service runs on port 3001
- Rails server communicates via HTTP POST
- Server-Sent Events (SSE) stream responses back
- ActionCable broadcasts SSE events to browser

✅ **Custom MCP Tools**
- MCP server created with `createSdkMcpServer`
- Tools make HTTP callbacks to Rails API
- Direct access to ActiveRecord via Rails endpoints

✅ **Agent Capabilities**
- File system access via `cwd` option
- Streaming responses via `includePartialMessages`
- Real-time progressive rendering in UI

✅ **Process Management**
- Both services run via Procfile.dev
- Clean separation of concerns
- Independent scaling possible

## Critical Configuration

**Node Service Environment Variables:**

```bash
RAILS_API_URL=http://localhost:4000  # Rails API endpoint
RAILS_ROOT=/path/to/rails/app        # For file system access
AGENT_SERVICE_PORT=3001              # Avoid PORT conflict with foreman
```

**MCP Tool with Rails Callback:**

```javascript
const railsDbServer = createSdkMcpServer({
  name: 'rails-db',
  version: '1.0.0',
  tools: [
    tool(
      'check_schema',
      'Check database schema',
      {},
      async () => {
        const response = await fetch(`${RAILS_API_URL}/api/schema`);
        const data = await response.json();
        return {
          content: [{
            type: 'text',
            text: `Tables: ${data.tables.join(', ')}\nCount: ${data.count}`
          }]
        };
      }
    )
  ]
});
```

**Agent Query Options:**

```javascript
query({
  prompt: message,
  options: {
    cwd: RAILS_ROOT,
    mcpServers: { 'rails-db': railsDbServer },
    allowedTools: ['mcp__rails-db__check_schema'],  // Must whitelist!
    includePartialMessages: true,                    // Enable streaming
    maxTurns: 10
  }
})
```

**Tool naming convention:** `mcp__<server_key>__<tool_name>`

## Implementation Files

### Node Service
- `agent-service/server.mjs` - Express server with SSE streaming
- `agent-service/tools.mjs` - MCP tool definitions
- `agent-service/package.json` - Dependencies

### Rails Integration
- `app/controllers/api/schema_controller.rb` - Database API endpoint
- `app/controllers/agent/typescript_controller.rb` - Chat controller
- `app/channels/agent/typescript_channel.rb` - SSE→ActionCable bridge
- `app/views/agent/typescript/index.html.erb` - Chat UI
- `app/javascript/controllers/typescript_sdk_chat_controller.js` - WebSocket client

### Configuration
- `Procfile.dev` - Multi-service startup
- `config/routes.rb` - Rails API routes
- `mise.local.toml` - Environment variables

## Authentication

Uses same authentication as Ruby SDK:

1. **OAuth Token** (recommended):
   ```bash
   npx claude setup-token
   # Add to mise.local.toml:
   ANTHROPIC_API_KEY = "sk-ant-api03-..."
   ```

2. **API Key**:
   ```bash
   # Add to mise.local.toml:
   ANTHROPIC_API_KEY = "sk-ant-api03-..."
   ```

## Test Results

**Query:** "What tables are in the database?"

**Behavior:**
1. Browser sends message via ActionCable
2. Rails receives message, POSTs to Node service
3. Node service calls `query()` with prompt
4. Agent recognizes need for database info
5. Agent calls `mcp__rails-db__check_schema` tool
6. Tool executes: `fetch('http://localhost:4000/api/schema')`
7. Rails API returns: `{tables: [...], count: N}`
8. Agent receives tool result, formulates response
9. Node streams response via SSE
10. Rails parses SSE events, broadcasts to ActionCable
11. Browser receives streaming deltas, renders progressively

**Result:** ✅ Lists all database tables correctly with real-time streaming

## Key Learnings

1. **Multi-Service Complexity** - Two separate processes add operational overhead
2. **Environment Variables Critical** - Node service needs RAILS_API_URL configured
3. **Port Configuration** - Use `AGENT_SERVICE_PORT` to avoid foreman's `PORT` variable
4. **SSE Buffer Parsing** - Must properly consume buffer to avoid duplicate events
5. **Rails API Pattern** - Clean separation via HTTP callbacks works well
6. **Tool Whitelisting Required** - Must explicitly allow tools in `allowedTools` array
7. **Streaming Delta Handling** - Track currentMessage state to append deltas correctly
8. **Default Port Mismatch** - Rails defaults to 3000, must document port overrides

## Issues Encountered & Solutions

### Issue 1: Duplicate Streaming Messages
**Problem:** SSE events processed multiple times, causing message duplication

**Root Cause:** Buffer not properly consumed after extracting events

**Solution:** Inline SSE parsing with proper buffer reassignment:
```ruby
while buffer.include?("\n\n")
  event_line, buffer = buffer.split("\n\n", 2)  # Updates buffer!
  # ... process event
end
```

## Architecture Comparison

**vs Ruby SDK (Spike 1):**

| Aspect | Ruby SDK | TypeScript SDK |
|--------|----------|----------------|
| **Process Model** | Single (Rails + gem subprocess) | Multi-service (Rails + Node) |
| **Complexity** | Lower | Higher |
| **Tool Execution** | In-process Ruby blocks | HTTP callbacks to Rails |
| **Language** | Pure Ruby | Mixed (TypeScript + Ruby) |
| **Deployment** | Single container | Multi-container or monolith |
| **Latency** | Lower (in-process) | Higher (HTTP overhead) |
| **Scaling** | Coupled with Rails | Independent scaling |

## Recommendation

✅ **USE WHEN:**
- You need to scale agent service independently
- You want to share Node service across multiple Rails instances
- Your team has strong TypeScript experience
- You're already running microservices

⚠️ **AVOID WHEN:**
- You want simplicity and low operational overhead
- You need lowest latency tool execution
- You prefer monolithic deployments
- You want minimal configuration

**For most Rails applications:** Ruby SDK (Spike 1) is simpler and sufficient.

**For production at scale:** TypeScript SDK offers better scalability and resource isolation.

## Code References

- MCP tool with HTTP callback: `agent-service/tools.mjs:8-28`
- SSE streaming setup: `agent-service/server.mjs:24-58`
- SSE buffer parsing: `app/channels/agent/typescript_channel.rb:49-69`
- Delta handling in Stimulus: `app/javascript/controllers/typescript_sdk_chat_controller.js:55-59`
- Rails API endpoint: `app/controllers/api/schema_controller.rb:6-12`
