require "open3"
require "json"
require "fileutils"

class ClaudeCodeAcpService
  attr_reader :session_id

  def initialize(session_id:)
    @session_id = session_id
    @config_path = generate_mcp_config
    @process_running = false
    @mutex = Mutex.new
  end

  def query(message, &block)
    @mutex.synchronize do
      return if @process_running

      @process_running = true
    end

    begin
      run_claude_code(message, &block)
    ensure
      cleanup
      @mutex.synchronize { @process_running = false }
    end
  end

  def cleanup
    FileUtils.rm_f(@config_path) if @config_path && File.exist?(@config_path)
  end

  private

  def generate_mcp_config
    config_dir = Rails.root.join("tmp", "mcp_configs")
    FileUtils.mkdir_p(config_dir)

    config_path = config_dir.join("mcp_config_#{session_id}.json")

    config = {
      mcpServers: {
        "rails-db": {
          command: "ruby",
          args: [Rails.root.join("app", "services", "mcp_server.rb").to_s],
          env: {}
        }
      }
    }

    File.write(config_path, JSON.pretty_generate(config))
    config_path.to_s
  end

  def run_claude_code(message, &block)
    command = build_command(message)

    env = {
      "ANTHROPIC_API_KEY" => ENV["ANTHROPIC_API_KEY"],
      "CLAUDE_CODE_OAUTH_TOKEN" => ENV["CLAUDE_CODE_OAUTH_TOKEN"]
    }.compact

    if env.empty?
      raise "No authentication configured. Please set either:\n" \
            "  ANTHROPIC_API_KEY=your_key\n" \
            "  or CLAUDE_CODE_OAUTH_TOKEN=your_token\n" \
            "in mise.local.toml and restart the server."
    end

    Rails.logger.debug "[ACP] Config path: #{@config_path}"
    Rails.logger.debug "[ACP] Config exists: #{File.exist?(@config_path)}"
    Rails.logger.debug "[ACP] Command: #{command.join(' ')}"

    Open3.popen3(env, *command) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      stdout.sync = true
      stderr.sync = true

      stderr_lines = []
      stderr_thread = Thread.new do
        stderr.each_line do |line|
          stderr_lines << line.chomp
          Rails.logger.debug "[Claude stderr] #{line.chomp}"
        end
      rescue StandardError => e
        Rails.logger.error "Error reading stderr: #{e.message}"
      end

      begin
        stdout.each_line do |line|
          next if line.strip.empty?

          event = parse_output_line(line)
          block.call(event) if event && block
        end
      rescue StandardError => e
        Rails.logger.error "Error reading stdout: #{e.message}"
        block.call({type: "error", content: e.message}) if block
      ensure
        stderr_thread.kill
      end

      status = wait_thr.value
      unless status.success?
        Rails.logger.error "Claude Code exited with status #{status.exitstatus}"
        Rails.logger.error "Command: #{command.join(' ')}"
        stderr_lines.last(5).each { |line| Rails.logger.error "  #{line}" }
        block.call({type: "error", content: "Claude Code exited with status #{status.exitstatus}. Check logs for details."}) if block
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to run Claude Code: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    block.call({type: "error", content: "Failed to start Claude Code: #{e.message}"}) if block
  end

  def build_command(message)
    [
      *find_claude_executable,
      "--print",
      "--verbose",
      "--dangerously-skip-permissions",
      "--output-format", "stream-json",
      "--mcp-config", @config_path,
      "--",
      message
    ]
  end

  def find_claude_executable
    npx_claude = Rails.root.join("node_modules", ".bin", "claude").to_s
    return [npx_claude] if File.executable?(npx_claude)

    ["npx", "@anthropic-ai/claude-code"]
  end

  def parse_output_line(line)
    return nil if line.strip.empty?

    event = JSON.parse(line)

    case event["type"]
    when "system"
      Rails.logger.info "[ACP] System event: #{event['subtype']}"
      if event["subtype"] == "init"
        mcp_servers = event["mcp_servers"] || []
        connected = mcp_servers.select { |s| s["status"] == "connected" }
        Rails.logger.info "[ACP] MCP servers connected: #{connected.map { |s| s['name'] }.join(', ')}"
      end
      nil

    when "assistant"
      message = event.dig("message")
      return nil unless message

      text_content = message["content"]
        .select { |c| c["type"] == "text" }
        .map { |c| c["text"] }
        .join("\n")

      {type: "assistant", content: text_content} if text_content.present?

    when "result"
      {type: "result", stop_reason: event["subtype"]}

    else
      Rails.logger.debug "[ACP] Unknown event type: #{event['type']}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.warn "[ACP] Failed to parse JSON: #{line[0..100]}"
    nil
  rescue StandardError => e
    Rails.logger.error "[ACP] Error parsing event: #{e.message}"
    Rails.logger.error "[ACP] Line: #{line[0..200]}"
    nil
  end
end
