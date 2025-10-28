class Agent::RubyChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user_id
  end

  def unsubscribed
  end

  def chat(data)
    message = data["message"]
    return unless message.present?

    broadcast_to current_user_id, {
      type: "user",
      content: message
    }

    Thread.new do
      ClaudeAgentService.query(message) do |msg|
        handle_agent_message(msg)
      end
    rescue => e
      broadcast_to current_user_id, {
        type: "error",
        content: "Error: #{e.message}"
      }
    end
  end

  private

  def current_user_id
    @current_user_id ||= connection.connection_identifier
  end

  def handle_agent_message(message)
    if message.is_a?(ClaudeAgentSDK::AssistantMessage)
      message.content.each do |block|
        if block.is_a?(ClaudeAgentSDK::TextBlock)
          broadcast_to current_user_id, {
            type: "assistant",
            content: block.text
          }
        end
      end
    end
  end
end
