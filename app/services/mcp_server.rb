#!/usr/bin/env ruby

require "json"
require "bundler/setup"
require_relative "../../config/environment"

class McpServer
  def initialize
    $stdout.sync = true
    $stderr.sync = true
    @request_id = 0
  end

  def run
    $stderr.puts "MCP Server starting..."

    $stdin.each_line do |line|
      begin
        request = JSON.parse(line.strip)
        handle_request(request)
      rescue JSON::ParserError => e
        send_error(nil, -32700, "Parse error: #{e.message}")
      rescue StandardError => e
        $stderr.puts "Error handling request: #{e.message}"
        $stderr.puts e.backtrace.first(5).join("\n")
        send_error(request&.dig("id"), -32603, "Internal error: #{e.message}")
      end
    end
  rescue Interrupt
    $stderr.puts "MCP Server shutting down..."
  end

  private

  def handle_request(request)
    method = request["method"]
    id = request["id"]
    params = request["params"] || {}

    case method
    when "initialize"
      handle_initialize(id, params)
    when "tools/list"
      handle_tools_list(id)
    when "tools/call"
      handle_tools_call(id, params)
    else
      send_error(id, -32601, "Method not found: #{method}")
    end
  end

  def handle_initialize(id, params)
    send_response(id, {
      protocolVersion: "2024-11-05",
      capabilities: {
        tools: {}
      },
      serverInfo: {
        name: "rails-db-mcp",
        version: "1.0.0"
      }
    })
  end

  def handle_tools_list(id)
    send_response(id, {
      tools: [
        {
          name: "check_schema",
          description: "Check database schema - returns list of tables and count",
          inputSchema: {
            type: "object",
            properties: {},
            required: []
          }
        }
      ]
    })
  end

  def handle_tools_call(id, params)
    tool_name = params["name"]
    arguments = params["arguments"] || {}

    case tool_name
    when "check_schema"
      execute_check_schema(id)
    else
      send_error(id, -32602, "Unknown tool: #{tool_name}")
    end
  end

  def execute_check_schema(id)
    ActiveRecord::Base.connection.reconnect!

    tables = ActiveRecord::Base.connection.tables
    count = tables.length

    send_response(id, {
      content: [
        {
          type: "text",
          text: "Tables: #{tables.join(', ')}\nCount: #{count}"
        }
      ]
    })
  rescue StandardError => e
    send_error(id, -32603, "Tool execution failed: #{e.message}")
  end

  def send_response(id, result)
    response = {
      jsonrpc: "2.0",
      id:,
      result:
    }
    $stdout.puts JSON.generate(response)
    $stdout.flush
  end

  def send_error(id, code, message)
    response = {
      jsonrpc: "2.0",
      id:,
      error: {
        code:,
        message:
      }
    }
    $stdout.puts JSON.generate(response)
    $stdout.flush
  end
end

if __FILE__ == $PROGRAM_NAME
  McpServer.new.run
end
