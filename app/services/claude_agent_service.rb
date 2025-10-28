require "claude_agent_sdk"

class ClaudeAgentService
  def self.query(prompt, &block)
    new.query(prompt, &block)
  end

  def query(prompt, &block)
    options = ClaudeAgentSDK::ClaudeAgentOptions.new(
      mcp_servers: { rails_db: mcp_server },
      allowed_tools: %w[mcp__rails_db__check_schema],
      max_turns: 10,
      cwd: Rails.root.to_s
    )

    ClaudeAgentSDK.query(prompt:, options:) do |message|
      block.call(message) if block
    end
  end

  private

  def mcp_server
    @mcp_server ||= ClaudeAgentSDK.create_sdk_mcp_server(
      name: "rails_db",
      version: "1.0.0",
      tools: [check_schema_tool]
    )
  end

  def check_schema_tool
    ClaudeAgentSDK.create_tool(
      "check_schema",
      "Check database schema - returns list of tables and count",
      {}
    ) do |_args|
      tables = ActiveRecord::Base.connection.tables
      {
        content: [{
          type: "text",
          text: "Tables: #{tables.join(', ')}\nCount: #{tables.count}"
        }]
      }
    end
  end
end
