import { Controller } from "@hotwired/stimulus"

// Handles auto-save for user settings and real-time BMI/BMR/TDEE calculations
// Auto-saves changes immediately without requiring a submit button
// Calculates metrics in real-time as user enters physical information
export default class extends Controller {
  static targets = ["metrics", "bmi", "bmiCategory", "bmr", "tdee", "metricsMessage", "bmiContainer", "bmrContainer", "tdeeContainer"]
  static values = {
    saveUrl: String,
    gender: String
  }

  connect() {
    // Set up debounced auto-save for all form inputs
    this.setupAutoSave()
    
    // Set up real-time metric calculations
    this.setupMetricCalculations()
    
    // Calculate metrics on initial load (this also handles initial display state)
    this.calculateMetrics()
  }

  // Sets up auto-save - saves immediately for most fields, debounced for text fields
  setupAutoSave() {
    // Track if there are unsaved changes
    this.hasUnsavedChanges = false
    this.isSaving = false
    this.saveTimer = null // Debounce timer for text fields
    
    // Prevent form submission (we handle it via AJAX)
    const form = this.element.querySelector('form')
    if (form) {
      form.addEventListener('submit', (e) => {
        e.preventDefault()
        this.saveSettings()
      })
    }
    
    // Save immediately before page unload if there are unsaved changes
    window.addEventListener('beforeunload', (e) => {
      // Clear any pending debounced save and save immediately
      if (this.saveTimer) {
        clearTimeout(this.saveTimer)
      }
      if (this.hasUnsavedChanges && !this.isSaving) {
        // Use synchronous XMLHttpRequest for beforeunload (only place it's acceptable)
        this.saveSettingsSync()
      }
    })
    
    // Find all form inputs and add change listeners
    const inputs = this.element.querySelectorAll('input, textarea, select')
    inputs.forEach(input => {
      // Use 'change' for checkboxes/radios, 'input' for text fields
      const eventType = input.type === 'checkbox' || input.type === 'radio' ? 'change' : 'input'
      input.addEventListener(eventType, (e) => {
        this.handleAutoSave(e.target)
      })
    })
  }

  // Handles auto-save - immediate for most fields, debounced for text fields
  handleAutoSave(input) {
    // Mark as having unsaved changes
    this.hasUnsavedChanges = true
    
    // Recalculate metrics immediately (no debounce needed)
    if (this.isPhysicalInfoField(input)) {
      this.calculateMetrics()
    }
    
    // Check if this is a text field that should be debounced
    const isTextField = input.tagName === 'TEXTAREA' || 
                       (input.type === 'text' || input.type === 'search' || input.type === 'email' || input.type === 'url')
    
    if (isTextField) {
      // Debounce text fields (wait 500ms after last keystroke)
      if (this.saveTimer) {
        clearTimeout(this.saveTimer)
      }
      this.saveTimer = setTimeout(() => {
        this.saveSettings()
      }, 500)
    } else {
      // Save immediately for checkboxes, radio buttons, number inputs, etc.
      this.saveSettings()
    }
  }

  // Checks if input is a physical information field that affects metrics
  isPhysicalInfoField(input) {
    const physicalFields = ['age', 'weight', 'height', 'gender', 'activity_level']
    return physicalFields.some(field => input.name && input.name.includes(field))
  }

  // Saves settings via AJAX using Turbo
  async saveSettings() {
    // Prevent multiple simultaneous saves
    if (this.isSaving) {
      return
    }
    
    const form = this.element.querySelector('form')
    if (!form) return

    this.isSaving = true
    const formData = new FormData(form)
    
    try {
      const response = await fetch(this.saveUrlValue, {
        method: 'PATCH',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml',
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'same-origin'
      })

      if (!response.ok) {
        console.error('Failed to save settings:', response.statusText)
        this.hasUnsavedChanges = true // Keep as unsaved if failed
      } else {
        // Mark as saved successfully
        this.hasUnsavedChanges = false
        
        // Parse and process Turbo Stream response
        const text = await response.text()
        if (text.includes('turbo-stream')) {
          Turbo.renderStreamMessage(text)
        }
      }
    } catch (error) {
      console.error('Error saving settings:', error)
      this.hasUnsavedChanges = true // Keep as unsaved if error
    } finally {
      this.isSaving = false
    }
  }

  // Synchronous save for beforeunload (only acceptable use of sync XHR)
  saveSettingsSync() {
    const form = this.element.querySelector('form')
    if (!form) return

    const formData = new FormData(form)
    const xhr = new XMLHttpRequest()
    
    // Use synchronous request (only acceptable in beforeunload)
    xhr.open('PATCH', this.saveUrlValue, false) // false = synchronous
    xhr.setRequestHeader('X-CSRF-Token', document.querySelector('meta[name="csrf-token"]').content)
    xhr.setRequestHeader('Accept', 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml')
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
    
    try {
      xhr.send(formData)
      if (xhr.status >= 200 && xhr.status < 300) {
        this.hasUnsavedChanges = false
      }
    } catch (error) {
      // Ignore errors in beforeunload - we tried our best
      console.error('Error saving settings on page unload:', error)
    }
  }

  // Sets up real-time metric calculations
  setupMetricCalculations() {
    // Listen for changes to physical info fields
    const physicalFields = this.element.querySelectorAll('[name*="age"], [name*="weight"], [name*="height"], [name*="gender"], [name*="activity_level"]')
    physicalFields.forEach(field => {
      field.addEventListener('input', () => this.calculateMetrics())
      field.addEventListener('change', () => this.calculateMetrics())
    })
  }

  // Calculates BMI, BMR, and TDEE in real-time
  calculateMetrics() {
    const age = parseFloat(this.getFieldValue('age'))
    const weight = parseFloat(this.getFieldValue('weight'))
    const height = parseFloat(this.getFieldValue('height'))
    const gender = this.getFieldValue('gender')
    const activityLevel = this.getFieldValue('activity_level')

    // Check if we have minimum required data
    const hasMinData = age > 0 && weight > 0 && height > 0

    if (!hasMinData) {
      this.showMetricsMessage('Fill in age, weight, and height to see calculated metrics')
      this.hideMetrics()
      return
    }

    // Calculate BMI
    const bmi = this.calculateBMI(weight, height)
    if (bmi) {
      this.updateBMI(bmi)
    }

    // Calculate BMR (requires age, weight, height)
    if (age > 0 && weight > 0 && height > 0) {
      const bmr = this.calculateBMR(weight, height, age, gender)
      if (bmr) {
        this.updateBMR(bmr)
        this.showBMR()
        
        // Calculate TDEE (requires BMR and activity level)
        if (activityLevel) {
          const tdee = this.calculateTDEE(bmr, activityLevel)
          if (tdee) {
            this.updateTDEE(tdee)
            this.showTDEE()
          } else {
            this.hideTDEE()
          }
        } else {
          this.hideTDEE()
        }
      } else {
        this.hideBMR()
        this.hideTDEE()
      }
    } else {
      this.hideBMR()
      this.hideTDEE()
    }

    // Hide message and show metrics (only if we have minimum data)
    if (hasMinData) {
      this.hideMetricsMessage()
      this.showMetrics()
    }
  }

  // Gets field value by name
  getFieldValue(fieldName) {
    const field = this.element.querySelector(`[name*="${fieldName}"]`)
    if (!field) return null

    if (field.type === 'checkbox') {
      return field.checked ? '1' : '0'
    } else if (field.type === 'radio') {
      const checked = this.element.querySelector(`[name*="${fieldName}"]:checked`)
      return checked ? checked.value : null
    } else {
      return field.value
    }
  }

  // Calculates BMI: weight (kg) / height (m)²
  calculateBMI(weight, height) {
    if (!weight || !height || weight <= 0 || height <= 0) return null
    const heightInMeters = height / 100.0
    return (weight / (heightInMeters ** 2)).toFixed(1)
  }

  // Calculates BMR using Mifflin-St Jeor Equation
  calculateBMR(weight, height, age, gender) {
    if (!weight || !height || !age || weight <= 0 || height <= 0 || age <= 0) return null
    
    const baseBMR = (10 * weight) + (6.25 * height) - (5 * age)
    
    // Adjust based on gender
    if (gender === 'male') {
      return Math.round(baseBMR + 5)
    } else if (gender === 'female') {
      return Math.round(baseBMR - 161)
    } else {
      // Use average if gender not specified
      return Math.round(((baseBMR + 5) + (baseBMR - 161)) / 2.0)
    }
  }

  // Calculates TDEE: BMR × Activity Multiplier
  calculateTDEE(bmr, activityLevel) {
    if (!bmr || !activityLevel) return null

    const multipliers = {
      'sedentary': 1.2,
      'lightly_active': 1.375,
      'moderately_active': 1.55,
      'very_active': 1.725,
      'extra_active': 1.9
    }

    const multiplier = multipliers[activityLevel] || 1.2
    return Math.round(bmr * multiplier)
  }

  // Gets BMI category
  getBMICategory(bmi) {
    if (!bmi) return null
    const bmiValue = parseFloat(bmi)
    if (bmiValue < 18.5) return 'Underweight'
    if (bmiValue < 25) return 'Normal weight'
    if (bmiValue < 30) return 'Overweight'
    return 'Obese'
  }

  // Updates BMI display
  updateBMI(bmi) {
    if (this.hasBmiTarget) {
      const category = this.getBMICategory(bmi)
      this.bmiTarget.textContent = bmi
      if (this.hasBmiCategoryTarget) {
        this.bmiCategoryTarget.textContent = category ? `(${category})` : ''
      }
    }
  }

  // Updates BMR display
  updateBMR(bmr) {
    if (this.hasBmrTarget) {
      this.bmrTarget.textContent = bmr
    }
  }

  // Updates TDEE display
  updateTDEE(tdee) {
    if (this.hasTdeeTarget) {
      this.tdeeTarget.textContent = tdee
    }
  }

  // Shows metrics section
  showMetrics() {
    if (this.hasMetricsTarget) {
      this.metricsTarget.style.display = 'flex'
    }
  }

  // Hides metrics section
  hideMetrics() {
    if (this.hasMetricsTarget) {
      this.metricsTarget.style.display = 'none'
    }
  }

  // Shows BMR
  showBMR() {
    if (this.hasBmrContainerTarget) {
      this.bmrContainerTarget.style.display = 'block'
    }
  }

  // Hides BMR
  hideBMR() {
    if (this.hasBmrContainerTarget) {
      this.bmrContainerTarget.style.display = 'none'
    }
  }

  // Shows TDEE
  showTDEE() {
    if (this.hasTdeeContainerTarget) {
      this.tdeeContainerTarget.style.display = 'block'
    }
  }

  // Hides TDEE
  hideTDEE() {
    if (this.hasTdeeContainerTarget) {
      this.tdeeContainerTarget.style.display = 'none'
    }
  }

  // Shows metrics message
  showMetricsMessage(message) {
    if (this.hasMetricsMessageTarget) {
      this.metricsMessageTarget.textContent = message
      this.metricsMessageTarget.style.display = 'block'
    }
  }

  // Hides metrics message
  hideMetricsMessage() {
    if (this.hasMetricsMessageTarget) {
      this.metricsMessageTarget.style.display = 'none'
    }
  }
}

