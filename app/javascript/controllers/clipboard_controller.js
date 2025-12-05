import { Controller } from "@hotwired/stimulus"

// Handles copying text to clipboard with visual feedback
// Usage: data-controller="clipboard" data-clipboard-text-value="text to copy"
// Or: data-controller="clipboard" data-clipboard-target="source" (copies from target element)
export default class extends Controller {
  static targets = ["source"]
  static values = { text: String }

  // Copy text to clipboard when button is clicked
  // Uses either the text value or the content from the source target
  async copy(event) {
    let textToCopy

    // If source target exists, format the text properly
    // For shopping lists, extract list items and format them cleanly
    if (this.hasSourceTarget) {
      // Check if this is a list (shopping list) - format items one per line
      const listItems = this.sourceTarget.querySelectorAll('li')
      if (listItems.length > 0) {
        // Extract text from each list item, removing bullet points and extra whitespace
        // Join with newlines for clean formatting
        textToCopy = Array.from(listItems)
          .map(li => {
            // Get text content and remove bullet point character (•) and extra whitespace
            return li.textContent.replace(/^[\s•]*/, '').trim()
          })
          .filter(item => item.length > 0) // Remove empty items
          .join('\n')
      } else {
        // Not a list, just get text content
        textToCopy = this.sourceTarget.textContent.trim()
      }
    } else if (this.hasTextValue) {
      textToCopy = this.textValue
    } else {
      console.error("Clipboard controller: No text value or source target provided")
      return
    }

    // Store the button element for feedback
    const button = event.currentTarget

    try {
      // Use modern Clipboard API if available
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(textToCopy)
        this.showSuccess(button)
      } else {
        // Fallback for older browsers
        this.fallbackCopy(textToCopy, button)
      }
    } catch (err) {
      console.error("Failed to copy text:", err)
      this.showError(button)
    }
  }

  // Fallback copy method for older browsers
  // Creates a temporary textarea, selects it, copies, then removes it
  fallbackCopy(text, button) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.left = "-999999px"
    document.body.appendChild(textarea)
    textarea.select()
    
    try {
      document.execCommand("copy")
      this.showSuccess(button)
    } catch (err) {
      console.error("Fallback copy failed:", err)
      this.showError(button)
    } finally {
      document.body.removeChild(textarea)
    }
  }

  // Show success feedback by temporarily changing button icon/text
  // Receives the button element that triggered the copy action
  showSuccess(button) {
    if (!button) return
    
    const originalHTML = button.innerHTML
    
    // Change to checkmark icon
    button.innerHTML = '<i class="bi bi-check-lg fs-6 text-success"></i>'
    button.classList.add("text-success")
    
    // Reset after 2 seconds
    setTimeout(() => {
      button.innerHTML = originalHTML
      button.classList.remove("text-success")
    }, 2000)
  }

  // Show error feedback
  // Receives the button element that triggered the copy action
  showError(button) {
    if (!button) return
    
    const originalHTML = button.innerHTML
    
    // Change to error icon
    button.innerHTML = '<i class="bi bi-x-lg fs-6 text-danger"></i>'
    button.classList.add("text-danger")
    
    // Reset after 2 seconds
    setTimeout(() => {
      button.innerHTML = originalHTML
      button.classList.remove("text-danger")
    }, 2000)
  }
}

