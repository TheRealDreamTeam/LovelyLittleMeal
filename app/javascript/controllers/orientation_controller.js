import { Controller } from "@hotwired/stimulus"

// Handles orientation changes and optimizes layout for portrait mode
// Shows a message or adjusts layout when device is rotated to landscape
export default class extends Controller {
  connect() {
    // Check initial orientation
    this.handleOrientationChange()
    
    // Listen for orientation changes
    window.addEventListener("orientationchange", () => {
      // Wait for orientation change to complete
      setTimeout(() => {
        this.handleOrientationChange()
      }, 100)
    })
    
    // Also listen for resize (handles some edge cases)
    window.addEventListener("resize", () => {
      this.handleOrientationChange()
    })
  }

  handleOrientationChange() {
    // Check if we're in landscape mode on a mobile device
    const isLandscape = window.innerWidth > window.innerHeight
    const isMobile = window.innerWidth < 992 // Bootstrap lg breakpoint
    
    if (isLandscape && isMobile) {
      // On mobile landscape, we could show a message or adjust layout
      // For now, we'll just ensure the layout adapts via CSS
      // The CSS media queries handle the actual layout adjustments
      this.element.classList.add("landscape-mode")
    } else {
      this.element.classList.remove("landscape-mode")
    }
  }
}

