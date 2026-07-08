import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "dropZone"]

  connect() {
    console.log("🚀 Drag test controller connected")
    console.log("Found cards:", this.cardTargets.length)
    console.log("Found drop zones:", this.dropZoneTargets.length)

    // Debug info
    console.log("Cards found:", this.cardTargets.map(c => c.dataset.leadId))
    console.log("Drop zones found:", this.dropZoneTargets.map(d => d.dataset.dropTarget))

    // Add drag listeners to cards
    this.cardTargets.forEach((card, index) => {
      console.log(`Setting up card ${index}:`, card.dataset.leadId)
      card.addEventListener('dragstart', this.handleDragStart.bind(this))
      card.addEventListener('dragend', this.handleDragEnd.bind(this))
    })

    // Add drop listeners to drop zones
    this.dropZoneTargets.forEach((target, index) => {
      console.log(`Setting up drop zone ${index}:`, target.dataset.dropTarget)
      target.addEventListener('dragover', this.handleDragOver.bind(this))
      target.addEventListener('drop', this.handleDrop.bind(this))
      target.addEventListener('dragenter', this.handleDragEnter.bind(this))
      target.addEventListener('dragleave', this.handleDragLeave.bind(this))
    })
  }

  handleDragStart(event) {
    console.log("🖱️ Drag started")
    const card = event.target.closest('.kanban-card')
    if (!card) return

    this.draggedCard = card
    this.draggedLeadId = card.dataset.leadId
    this.draggedCurrentStage = card.dataset.currentStage

    console.log(`Dragging lead ${this.draggedLeadId} from stage ${this.draggedCurrentStage}`)

    card.classList.add('dragging')
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', this.draggedLeadId)
  }

  handleDragEnd(event) {
    console.log("🛑 Drag ended")
    const card = event.target.closest('.kanban-card')
    if (card) {
      card.classList.remove('dragging')
    }
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
  }

  handleDragEnter(event) {
    event.preventDefault()
    const dropZone = event.target.closest('[data-drop-target]')
    if (dropZone) {
      dropZone.classList.add('drag-over')
      console.log("🎯 Drag enter:", dropZone.dataset.dropTarget)
    }
  }

  handleDragLeave(event) {
    const dropZone = event.target.closest('[data-drop-target]')
    if (dropZone && !dropZone.contains(event.relatedTarget)) {
      dropZone.classList.remove('drag-over')
      console.log("🚪 Drag leave:", dropZone.dataset.dropTarget)
    }
  }

  async handleDrop(event) {
    event.preventDefault()
    console.log("📥 Drop triggered")

    const dropZone = event.target.closest('[data-drop-target]')
    if (!dropZone) {
      console.error("❌ No drop zone found")
      return
    }

    const targetStage = dropZone.dataset.dropTarget
    dropZone.classList.remove('drag-over')

    console.log(`📦 Dropping lead ${this.draggedLeadId} into stage: ${targetStage}`)

    if (targetStage === this.draggedCurrentStage) {
      console.log("⚠️ Same stage, skipping")
      return
    }

    try {
      console.log("🔄 Attempting AJAX update...")
      const success = await this.updateLeadStage(this.draggedLeadId, targetStage)

      if (success) {
        console.log("✅ Update successful, moving card")
        this.moveCardToColumn(this.draggedLeadId, targetStage)
        this.showMessage("Success: Lead stage updated", "success")
      } else {
        console.log("❌ Update failed")
        this.showMessage("Error: Failed to update lead stage", "error")
      }
    } catch (error) {
      console.error("💥 Exception:", error)
      this.showMessage("Error: " + error.message, "error")
    }
  }

  async updateLeadStage(leadId, newStage) {
    console.log(`🌐 Making AJAX request: PATCH /admin/leads/${leadId}/convert_stage`)

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    if (!csrfToken) {
      console.error("❌ No CSRF token found")
      return false
    }

    const url = `/admin/leads/${leadId}/convert_stage`
    const payload = { stage: newStage }

    console.log("📤 Sending payload:", payload)

    try {
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
      })

      console.log(`📨 Response status: ${response.status}`)

      if (!response.ok) {
        const errorText = await response.text()
        console.error("❌ Error response:", errorText)
        throw new Error(`HTTP ${response.status}: ${errorText}`)
      }

      const result = await response.json()
      console.log("📬 Response data:", result)

      return result.success !== false
    } catch (error) {
      console.error("💥 Fetch error:", error)
      throw error
    }
  }

  moveCardToColumn(leadId, targetStage) {
    const card = document.querySelector(`[data-lead-id="${leadId}"]`)
    const targetColumn = document.querySelector(`[data-drop-target="${targetStage}"]`)

    if (!card || !targetColumn) {
      console.error("❌ Could not find card or target column for DOM move")
      return
    }

    console.log("🔄 Moving card in DOM")

    // Update card's stage data
    card.dataset.currentStage = targetStage

    // Remove any empty state
    const emptyState = targetColumn.querySelector('.empty-column')
    if (emptyState) {
      emptyState.remove()
    }

    // Move card
    targetColumn.appendChild(card)

    // Update counts (simple version)
    this.updateColumnCounts()

    console.log("✅ Card moved successfully")
  }

  updateColumnCounts() {
    document.querySelectorAll('.kanban-column').forEach(column => {
      const stage = column.querySelector('[data-drop-target]')?.dataset.dropTarget
      const cardCount = column.querySelectorAll('.kanban-card').length
      const badge = column.querySelector('.badge')

      if (badge && stage) {
        badge.textContent = cardCount
        console.log(`📊 Updated ${stage} count to: ${cardCount}`)
      }
    })
  }

  showMessage(message, type) {
    console.log(`💬 ${type.toUpperCase()}: ${message}`)

    // Simple alert for now - can be replaced with toast
    if (type === "success") {
      // Green border flash
      document.body.style.border = "3px solid green"
      setTimeout(() => { document.body.style.border = "none" }, 1000)
    } else {
      // Red border flash
      document.body.style.border = "3px solid red"
      setTimeout(() => { document.body.style.border = "none" }, 1000)
    }

    // Also show browser notification
    alert(message)
  }
}