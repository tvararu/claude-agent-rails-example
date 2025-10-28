import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["messages", "input", "submit", "form"]
  static values = { channel: String }

  connect() {
    this.currentMessage = null
    this.subscription = consumer.subscriptions.create(
      { channel: this.channelValue },
      {
        received: (data) => this.handleMessage(data),
        connected: () => this.handleConnected(),
        disconnected: () => this.handleDisconnected()
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  send(event) {
    event.preventDefault()
    const message = this.inputTarget.value.trim()
    if (!message) return

    this.subscription.perform("chat", { message })
    this.inputTarget.value = ""
    this.setLoading(true)
  }

  handleMessage(data) {
    if (data.type === "user") {
      this.appendMessage("user", data.content)
    } else if (data.type === "assistant_delta") {
      this.appendDelta(data.content)
    } else if (data.type === "assistant") {
      if (!this.currentMessage) {
        this.appendMessage("assistant", data.content)
      }
    } else if (data.type === "error") {
      this.currentMessage = null
      this.appendMessage("error", data.content)
      this.setLoading(false)
    } else if (data.type === "result") {
      this.currentMessage = null
      this.setLoading(false)
    }
  }

  appendDelta(text) {
    if (!this.currentMessage) {
      this.currentMessage = document.createElement("div")
      this.currentMessage.className = this.getMessageClass("assistant")
      this.messagesTarget.appendChild(this.currentMessage)
    }

    this.currentMessage.textContent += text
    this.scrollToBottom()
  }

  appendMessage(type, content) {
    const div = document.createElement("div")
    div.className = this.getMessageClass(type)
    div.textContent = content
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()

    if (type === "assistant" || type === "error") {
      this.setLoading(false)
    }
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  handleConnected() {
    console.log("Connected to Agent::TypescriptChannel")
  }

  handleDisconnected() {
    console.log("Disconnected from Agent::TypescriptChannel")
  }

  getMessageClass(type) {
    const base = "rounded-lg p-3 text-sm"
    switch(type) {
      case "user":
        return `${base} bg-blue-100 text-blue-900 self-end max-w-md`
      case "assistant":
        return `${base} bg-gray-100 text-gray-900 max-w-3xl`
      case "error":
        return `${base} bg-red-100 text-red-900`
      default:
        return base
    }
  }

  setLoading(isLoading) {
    this.submitTarget.disabled = isLoading
    this.inputTarget.disabled = isLoading
  }
}
