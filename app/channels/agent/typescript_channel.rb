require "net/http"
require "uri"
require "json"

class Agent::TypescriptChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user_id
  end

  def chat(data)
    message = data["message"]
    return unless message.present?

    broadcast_to current_user_id, {
      type: "user",
      content: message
    }

    Thread.new do
      query_node_service(message)
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

  def query_node_service(message)
    node_url = ENV.fetch("NODE_SERVICE_URL", "http://localhost:3001")
    uri = URI("#{node_url}/agent/query")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = { message: }.to_json

    http.request(request) do |response|
      unless response.is_a?(Net::HTTPSuccess)
        raise "Node service error: #{response.code} #{response.message}"
      end

      buffer = ""
      response.read_body do |chunk|
        buffer += chunk

        while buffer.include?("\n\n")
          event_line, buffer = buffer.split("\n\n", 2)
          next unless event_line.start_with?("data: ")

          event_data = event_line.sub("data: ", "")
          next if event_data == "[DONE]"

          begin
            event = JSON.parse(event_data)
            handle_event(event)
          rescue JSON::ParserError => e
            Rails.logger.error(
              "Failed to parse SSE event: #{e.message}"
            )
          end
        end
      end
    end
  end

  def handle_event(event)
    case event["type"]
    when "assistant_delta"
      broadcast_to current_user_id, {
        type: "assistant_delta",
        content: event["content"]
      }
    when "assistant"
      broadcast_to current_user_id, {
        type: "assistant",
        content: event["content"]
      }
    when "result"
      broadcast_to current_user_id, {
        type: "result",
        cost: event["cost"],
        turns: event["turns"]
      }
    when "error"
      broadcast_to current_user_id, {
        type: "error",
        content: event["content"]
      }
    end
  end
end
