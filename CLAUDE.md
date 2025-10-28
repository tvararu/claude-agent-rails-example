# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rails 8 technical spike exploring three approaches to integrating Claude Code's agentic capabilities into a Rails application. The goal is to compare feasibility, complexity, and developer experience for each approach.

## Three Integration Approaches

1. **Ruby SDK** (`/agent/claude-agent-sdk-ruby`)
   - Pure Ruby via `claude-agent-sdk-ruby` gem
   - Gem spawns Node subprocesses to run Claude Code CLI
   - See `docs/spike-ruby-sdk.md`

2. **TypeScript SDK** (`/agent/claude-agent-sdk-typescript`)
   - Node.js service with `@anthropic-ai/claude-agent-sdk`
   - Rails communicates via HTTP POST/SSE
   - See `docs/spike-typescript-sdk.md`

3. **Agent Client Protocol** (`/agent/claude-code-acp`)
   - JSON-RPC over stdio using `@zed-industries/claude-code-acp`
   - Pure Ruby ACP client implementation
   - See `docs/spike-acp.md`

## Development Commands

Start the development server:
```bash
bin/dev
```

This runs foreman with `Procfile.dev`, which starts:
- Rails server on port 3000
- Tailwind CSS watcher

Run Rails console:
```bash
bin/rails console
```

Database operations:
```bash
bin/rails db:migrate
bin/rails db:seed
bin/rails db:reset
```

## Critical Success Criteria

Each implementation route must demonstrate:
- Chat interface that opens and connects
- Response to: "What tables are in the database?"
- Custom `check_schema` tool that queries `ActiveRecord::Base.connection.tables`
- Real-time streaming responses

## Key Implementation Requirements

### Custom Tool: `check_schema`

All three approaches must implement this tool:
- Returns list of database tables
- Returns table count
- Executed via Ruby code accessing ActiveRecord

Test query: "What tables are in the database?"

Expected behavior:
1. Agent recognizes need for database info
2. Agent calls `check_schema` tool
3. Tool executes: `ActiveRecord::Base.connection.tables`
4. Agent formulates response with table list

### Streaming Requirements

Responses must stream in real-time:
- ActionCable for Ruby SDK and ACP approaches
- HTTP SSE for TypeScript SDK approach
- UI updates progressively, not all at once

### Process Management Considerations

**Ruby SDK:**
- Gem manages Claude Code CLI subprocess lifecycle
- No manual start/stop required

**TypeScript SDK:**
- Add Node service to `Procfile.dev`
- Rails makes HTTP requests to `localhost:3001` (or configured port)
- Node service calls back to Rails API for database operations

**ACP:**
- Spawn `claude-code-acp` subprocess from Rails
- Communicate via JSON-RPC 2.0 over stdin/stdout
- Track sessions via sessionId

## Architecture Notes

### Rails 8 Specifics

- Uses SQLite3 database (check: `config/database.yml`)
- Solid Queue for background jobs
- Solid Cable for ActionCable
- Solid Cache for caching
- Propshaft for assets
- Tailwind CSS for styling

### Database Access

Each approach handles database queries differently:

**Ruby SDK:**
- Direct ActiveRecord access in custom tool

**TypeScript SDK:**
- Node tool calls Rails API endpoint (e.g., `GET /api/schema`)
- Rails endpoint returns JSON: `{tables: [...], count: N}`

**ACP:**
- Intercept `session/update` tool call notifications
- Execute Ruby code locally
- Return results via `session/approve_tool_call`

## Open Questions to Answer

### Ruby SDK
- How does the gem expose custom tools? (MCP? Options hash? Hooks?)
- How to register tools with the agent?
- Does it support concurrent sessions?

### TypeScript SDK
- Best process management for dev vs production?
- How to share file access between Rails and Node?
- Authentication strategy for Rails API callbacks?

### ACP
- Is implementing JSON-RPC client worth it vs existing library?
- Which tool approach is simplest: ACP built-in, MCP server, or client proxy?
- Can we avoid Node entirely?

## Spike Deliverables

1. Working implementations at all three routes
2. Updated spike docs with:
   - Answers to open questions
   - Implementation notes
   - Blockers/challenges encountered
3. Recommendation: which approach for production use?

## Important Notes

- This is exploratory code, not production-ready
- No test coverage required for spike
- Simple UI is fine - focus on functionality
- Document surprises and learnings
- If something doesn't work, that's valuable data

## Memories

- Use context7 MCP for looking up
- Use uithub (not a typo) for exploring GitHub repos
- Don't write unnecessary comments
- Don't remove existing comments (especially model annotations)
- Prefer `it` (or `_1`, `_2`) instead of `|x| x` for one-liners
- Don't use `rails console` or interactive REPLs, write one-off scripts
- Don't run complex `rails runner` one-liners, write to `./tmp/` instead, no cat
- Don't write tests, they're not necessary in this project
- Environment variables go in mise.toml and mise.local.toml (gitignored)
- Always generate migrations using `rails g`
- Use Struct, never OpenStruct
- Always use hash shorthand, e.g. { key: } instead of { key: key }
- Use the recommended Tailwind classes order
- Try to wrap all code at 80 chars
- Prefer no-JS solutions first
- Always use %i[] and other shorthands for arrays of symbols/words
