# Spike Results: Claude Agent SDK (Ruby)

**Status:** ✅ **SUCCESS**

## Summary

The `claude-agent-sdk` gem (v0.2.1) successfully integrates with Rails and supports custom MCP tools when properly configured.

## What Works

✅ **Chat Interface**
- ActionCable streaming with real-time updates
- Progressive message rendering
- Concurrent sessions work independently

✅ **Custom MCP Tools**
- In-process MCP server creation via `create_sdk_mcp_server`
- Tool execution with Ruby blocks
- Direct ActiveRecord database access

✅ **Agent Capabilities**
- File system access within Rails directory
- Subprocess management handled automatically
- Streaming responses via `AssistantMessage` blocks

## Critical Configuration

**MCP tools must be explicitly whitelisted:**

```ruby
options = ClaudeAgentSDK::ClaudeAgentOptions.new(
  mcp_servers: { rails_db: mcp_server },
  allowed_tools: %w[mcp__rails_db__check_schema],  # ← Required!
  max_turns: 10,
  cwd: Rails.root.to_s
)
```

**Tool naming convention:** `mcp__<server_key>__<tool_name>`

## Implementation Files

- `app/services/claude_agent_service.rb` - MCP tool wrapper
- `app/controllers/agent/ruby_controller.rb` - Chat controller
- `app/channels/agent/ruby_channel.rb` - ActionCable streaming
- `app/views/agent/ruby/index.html.erb` - Chat UI
- `app/javascript/controllers/ruby_sdk_chat_controller.js` - WebSocket client
- `config/initializers/claude_code_cli.rb` - PATH setup for local CLI

## Authentication

Supports two methods (choose one):

1. **OAuth Token** (recommended):
   ```bash
   npx claude setup-token
   # Add to mise.local.toml:
   CLAUDE_CODE_OAUTH_TOKEN = "sk-ant-oat01-..."
   ```

2. **API Key**:
   ```bash
   # Add to mise.local.toml:
   ANTHROPIC_API_KEY = "sk-ant-api03-..."
   ```

## Test Results

**Query:** "What tables are in the database?"

**Behavior:**
1. Agent recognizes need for database info
2. Calls `mcp__rails_db__check_schema` tool
3. Tool executes: `ActiveRecord::Base.connection.tables`
4. Agent receives table list with count
5. Streams response back via ActionCable

**Result:** ✅ Lists all database tables correctly

## Key Learnings

1. **MCP Tools Work** - Initial blocker was missing `allowed_tools` configuration
2. **No Global State** - Each query is stateless; multi-turn requires manual history
3. **Thread Safe** - Uses Ruby threads safely within ActionCable
4. **Local CLI** - Can use npm-installed CLI instead of global install
5. **Subprocess Overhead** - Gem spawns/reuses Claude Code CLI process per query

## Recommendation

✅ **RECOMMENDED** for Rails integration when:
- You need custom tools with direct Ruby/Rails access
- Real-time streaming is required
- You want in-process tool execution (no separate MCP server)

## Code References

- Tool creation: `app/services/claude_agent_service.rb:31-44`
- MCP server setup: `app/services/claude_agent_service.rb:23-28`
- Options configuration: `app/services/claude_agent_service.rb:9-14`
- Streaming handler: `app/channels/agent/ruby_channel.rb:36-47`
