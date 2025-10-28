# Technical Spike: Claude Agent SDK (Ruby)

## Overview

Integration using `claude-agent-sdk-ruby` gem for pure Ruby implementation.

**Route:** `/agent/claude-agent-sdk-ruby`

## Prerequisites

- `claude-agent-sdk-ruby` gem installed
- Claude Code CLI installed globally (`npm install -g @anthropic-ai/claude-code`)
- Anthropic API key configured

## Architecture

```
Browser (WebSocket)
   ↓
Rails ActionCable Channel
   ↓
Ruby Service wrapping claude-agent-sdk-ruby
   ↓ (gem spawns/manages)
Claude Code CLI subprocess (Node.js)
   ↓
Anthropic API
```

## How It Should Work

### User Flow

1. User navigates to `/agent/claude-agent-sdk-ruby`
2. Browser opens WebSocket connection via ActionCable
3. User types message in chat interface
4. Message sent to ActionCable channel
5. Channel delegates to service that uses the Ruby gem
6. Gem spawns Claude Code CLI process (if not already running)
7. Agent responses stream back through the gem
8. Service broadcasts messages to ActionCable
9. Browser receives and displays responses in real-time

### Agent Capabilities

The agent should be able to:
- Read files from the Rails application directory
- Access database schema information via custom tool
- Respond to questions about the Rails app structure
- Execute safe commands (read-only by default)

### Custom Tool Integration

A custom `check_schema` tool should be available to the agent that:
- Returns list of database tables
- Returns table count
- Executed via Ruby code (no subprocess calls)

**Research Question:** How does the gem expose custom tools to the agent? Via MCP? Via hooks? Via the options hash?

### Message Flow

**User message:**
```
"What tables are in the database?"
```

**Expected agent behavior:**
1. Agent recognizes it needs database information
2. Agent calls `check_schema` tool
3. Tool executes Ruby code: `ActiveRecord::Base.connection.tables`
4. Agent receives tool result
5. Agent formulates response with table list

**Response stream:**
```
Assistant: Let me check the database schema for you.
[tool execution happens]
Assistant: The database has 5 tables: users, posts, comments, tags, and sessions.
```

### Process Management

The gem should handle:
- Spawning Claude Code CLI subprocess automatically
- Managing subprocess lifecycle
- Cleaning up on Rails process exit
- Reconnecting if subprocess dies

Developer should not need to manually start/stop the CLI.

## Testing Acceptance Criteria

### Basic Functionality

1. **Visit route**
   - Navigate to `http://localhost:3000/agent/claude-agent-sdk-ruby`
   - Page loads with chat interface
   - No errors in browser console or Rails logs

2. **Simple conversation**
   - Type: "Hello, can you see me?"
   - Receive response within 3 seconds
   - Response acknowledges the message

3. **File access**
   - Type: "What files are in the app/models directory?"
   - Agent lists model files
   - File names match actual filesystem

4. **Custom tool execution**
   - Type: "What tables are in the database?"
   - Agent uses `check_schema` tool
   - Response includes actual table names from DB
   - Table count is accurate

5. **Multi-turn conversation**
   - Type: "What tables are in the database?"
   - Receive response
   - Type: "Tell me more about the users table"
   - Agent maintains context from previous question
   - Response relates to users table specifically

6. **Error handling**
   - Type: "Delete all records from users table"
   - Agent should refuse or ask for confirmation
   - No destructive action taken

7. **Streaming**
   - Type: "List all tables and describe each one"
   - Response appears progressively (not all at once)
   - UI updates as tokens arrive

### Process Management

8. **Automatic startup**
   - Rails server starts
   - Visit `/agent/claude-agent-sdk-ruby`
   - Claude CLI subprocess spawns automatically
   - No manual intervention needed

9. **Graceful shutdown**
   - Stop Rails server
   - Claude CLI subprocess terminates
   - No orphaned processes

## Open Questions

1. **Custom tool registration**: How are tools defined and registered with the gem? Is it via:
   - Initializer configuration?
   - Per-request options?
   - MCP server integration?
   - Hooks/callbacks?

2. **Permission model**: How do we control what the agent can do?
   - Is there a permission callback system?
   - Can we approve/deny individual tool uses?
   - Is there a sandbox mode for testing?

3. **State management**: How are conversations managed?
   - Does the gem maintain session state?
   - Do we need to manually track conversation history?
   - Can we have multiple concurrent sessions?

4. **Error recovery**: What happens when:
   - Claude CLI crashes?
   - API rate limit hit?
   - Network connection lost?

5. **Configuration**: Where does config live?
   - API key storage?
   - Default tool permissions?
   - Working directory specification?

## Success Criteria

The spike is successful if we can:
- Send a message and receive a response
- Execute the custom `check_schema` tool
- Understand how to add more custom tools
- Stream responses in real-time
- Document the gem's capabilities and limitations
