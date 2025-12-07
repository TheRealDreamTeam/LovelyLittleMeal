import { Controller } from "@hotwired/stimulus"

// Auto-dismisses flash messages (alerts/toasts) after a specified delay
// Uses Bootstrap's alert dismiss functionality to properly fade out
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 3000 } // Default 3 seconds
  }

  connect() {
    // Auto-dismiss the alert after the specified delay
    // Uses Bootstrap's built-in dismiss functionality for proper fade animation
    this.timeout = setTimeout(() => {
      // Find the close button and trigger click to properly dismiss
      const closeButton = this.element.querySelector('[data-bs-dismiss="alert"]')
      if (closeButton) {
        closeButton.click()
      } else {
        // Fallback: manually remove if no close button found
        this.element.remove()
      }
    }, this.delayValue)
  }

  disconnect() {
    // Clear timeout if component is removed before timeout completes
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

