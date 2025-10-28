class Agent::AcpChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user_id
  end

  def unsubscribed
    cleanup_service
  end

  def chat(data)
    message = data["message"]
    return unless message.present?

    broadcast_to current_user_id, {type: "user", content: message}

    Thread.new do
      handle_query(message)
    rescue StandardError => e
      Rails.logger.error "Error in chat handler: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      broadcast_to current_user_id, {type: "error", content: "Error: #{e.message}"}
    end
  end

  private

  def current_user_id
    connection_id
  end

  def service
    @service ||= ClaudeCodeAcpService.new(session_id: current_user_id)
  end

  def handle_query(message)
    service.query(message) do |event|
      broadcast_to current_user_id, event
    end
  rescue StandardError => e
    Rails.logger.error "Service query failed: #{e.message}"
    broadcast_to current_user_id, {type: "error", content: e.message}
  end

  def cleanup_service
    return unless @service

    @service.cleanup
    @service = nil
  end
end
