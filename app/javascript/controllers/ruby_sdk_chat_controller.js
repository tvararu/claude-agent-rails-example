import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["messages", "input", "submit", "form"]
  static values = { channel: String }

  connect() {
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
    const div = document.createElement("div")
    div.className = this.getMessageClass(data.type)
    div.textContent = data.content
    this.messagesTarget.appendChild(div)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight

    if (data.type === "assistant" || data.type === "error") {
      this.setLoading(false)
    }
  }

  handleConnected() {
    console.log("Connected to Agent::RubyChannel")
  }

  handleDisconnected() {
    console.log("Disconnected from Agent::RubyChannel")
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
