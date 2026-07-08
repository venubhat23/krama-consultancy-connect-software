import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "dropTarget"]

  connect() {
    console.log("Drag controller connected")
    console.log("Found cards:", this.cardTargets.length)
    console.log("Found drop targets:", this.dropTargetTargets.length)
    this.boundDragStart = this.dragStart.bind(this)
    this.boundDragEnd = this.dragEnd.bind(this)
    this.boundDragOver = this.dragOver.bind(this)
    this.boundDrop = this.drop.bind(this)

    // Add event listeners to all draggable cards
    this.cardTargets.forEach(card => {
      card.addEventListener('dragstart', this.boundDragStart)
      card.addEventListener('dragend', this.boundDragEnd)
    })

    // Add event listeners to all drop zones
    this.dropTargetTargets.forEach(target => {
      target.addEventListener('dragover', this.boundDragOver)
      target.addEventListener('drop', this.boundDrop)
      target.addEventListener('dragenter', this.dragEnter.bind(this))
      target.addEventListener('dragleave', this.dragLeave.bind(this))
    })
  }

  disconnect() {
    // Clean up event listeners
    this.cardTargets.forEach(card => {
      card.removeEventListener('dragstart', this.boundDragStart)
      card.removeEventListener('dragend', this.boundDragEnd)
    })

    this.dropTargetTargets.forEach(target => {
      target.removeEventListener('dragover', this.boundDragOver)
      target.removeEventListener('drop', this.boundDrop)
      target.removeEventListener('dragenter', this.dragEnter.bind(this))
      target.removeEventListener('dragleave', this.dragLeave.bind(this))
    })
  }

  dragStart(event) {
    console.log("Drag start triggered", event.target)
    const card = event.target.closest('.kanban-card')
    if (!card) {
      console.error("Could not find kanban card")
      return
    }

    card.classList.add('dragging')

    // Store lead data
    this.draggedLeadId = card.dataset.leadId
    this.draggedCurrentStage = card.dataset.currentStage

    console.log("Dragging lead:", this.draggedLeadId, "from stage:", this.draggedCurrentStage)

    // Set drag data
    event.dataTransfer.setData('text/plain', this.draggedLeadId)
    event.dataTransfer.effectAllowed = 'move'

    // Show loading overlay
    this.showLoading()
  }

  dragEnd(event) {
    const card = event.target
    card.classList.remove('dragging')
    this.hideLoading()
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
  }

  dragEnter(event) {
    event.preventDefault()
    const dropZone = event.target.closest('[data-drop-target]')
    if (dropZone) {
      const targetStage = dropZone.dataset.dropTarget

      // Validate if this move is allowed
      if (this.canMoveToStage(this.draggedCurrentStage, targetStage)) {
        dropZone.classList.add('drag-over', 'drop-valid')
      } else {
        dropZone.classList.add('drag-over', 'drop-invalid')
      }
    }
  }

  dragLeave(event) {
    const dropZone = event.target.closest('[data-drop-target]')
    if (dropZone && !dropZone.contains(event.relatedTarget)) {
      dropZone.classList.remove('drag-over', 'drop-valid', 'drop-invalid')
    }
  }

  async drop(event) {
    event.preventDefault()
    console.log("Drop triggered", event.target)

    const dropZone = event.target.closest('[data-drop-target]')
    if (!dropZone) {
      console.error("Could not find drop target")
      return
    }

    const targetStage = dropZone.dataset.dropTarget
    console.log("Dropping on stage:", targetStage)

    // Clean up drag styling
    dropZone.classList.remove('drag-over', 'drop-valid', 'drop-invalid')

    // Don't proceed if dropping in same stage
    if (targetStage === this.draggedCurrentStage) {
      console.log("Dropping in same stage, skipping")
      return
    }

    // Validate move
    if (!this.canMoveToStage(this.draggedCurrentStage, targetStage)) {
      console.error("Invalid stage transition")
      this.showError('Invalid stage transition')
      return
    }

    try {
      console.log("Attempting to update lead stage:", this.draggedLeadId, "to:", targetStage)
      // Update stage via AJAX
      const success = await this.updateLeadStage(this.draggedLeadId, targetStage)

      if (success) {
        console.log("Stage update successful")
        // Move the card in DOM
        this.moveCardToColumn(this.draggedLeadId, targetStage)
        this.updateColumnCounts()
        this.showSuccess('Lead stage updated successfully')
      } else {
        console.error("Stage update failed")
        this.showError('Failed to update lead stage')
      }
    } catch (error) {
      console.error('Error updating lead stage:', error)
      this.showError('An error occurred while updating the lead')
    }
  }

  async updateLeadStage(leadId, newStage) {
    console.log("updateLeadStage called with:", leadId, newStage)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    console.log("CSRF Token:", csrfToken ? "Found" : "Missing")

    const url = `/admin/leads/${leadId}/convert_stage`
    console.log("Making request to:", url)

    try {
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          stage: newStage
        })
      })

      console.log("Response status:", response.status)
      console.log("Response ok:", response.ok)

      if (response.ok) {
        const result = await response.json()
        console.log("Response data:", result)
        return result.success !== false
      } else {
        const errorText = await response.text()
        console.error("Error response:", errorText)
      }
    } catch (fetchError) {
      console.error("Fetch error:", fetchError)
    }

    return false
  }

  moveCardToColumn(leadId, targetStage) {
    const card = document.querySelector(`[data-lead-id="${leadId}"]`)
    const targetColumn = document.querySelector(`[data-drop-target="${targetStage}"]`)

    if (card && targetColumn) {
      // Update card's current stage data
      card.dataset.currentStage = targetStage

      // Remove empty state if present
      const emptyState = targetColumn.querySelector('.empty-column')
      if (emptyState) {
        emptyState.remove()
      }

      // Add animation class
      card.classList.add('just-moved')

      // Move to new column at the top (prepend instead of append)
      targetColumn.insertBefore(card, targetColumn.firstChild)

      // Remove animation after completion
      setTimeout(() => {
        card.classList.remove('just-moved')
      }, 300)

      // Check if source column is now empty
      this.checkAndShowEmptyState()
    }
  }

  updateColumnCounts() {
    // Update badge counts for each column
    document.querySelectorAll('.kanban-column').forEach(column => {
      const stage = column.querySelector('[data-drop-target]').dataset.dropTarget
      const cardCount = column.querySelectorAll('.kanban-card').length
      const badge = column.querySelector('.badge')

      if (badge) {
        badge.textContent = cardCount
      }
    })
  }

  checkAndShowEmptyState() {
    document.querySelectorAll('.kanban-column-body').forEach(columnBody => {
      const cards = columnBody.querySelectorAll('.kanban-card')
      const emptyState = columnBody.querySelector('.empty-column')

      if (cards.length === 0 && !emptyState) {
        // Add empty state
        columnBody.innerHTML = `
          <div class="empty-column">
            <i class="bi bi-inbox text-muted"></i>
            <p class="text-muted mb-0">No leads</p>
          </div>
        `
      }
    })
  }

  canMoveToStage(currentStage, targetStage) {
    // For now, allow all stage transitions except to/from converted and lead_closed
    const restrictedFromStages = ['converted', 'lead_closed']
    const restrictedToStages = []

    if (restrictedFromStages.includes(currentStage)) {
      console.log("Cannot move from restricted stage:", currentStage)
      return false
    }

    if (restrictedToStages.includes(targetStage)) {
      console.log("Cannot move to restricted stage:", targetStage)
      return false
    }

    return currentStage !== targetStage
  }

  showLoading() {
    const loading = document.getElementById('kanban-loading')
    if (loading) {
      loading.classList.remove('d-none')
    }
  }

  hideLoading() {
    const loading = document.getElementById('kanban-loading')
    if (loading) {
      loading.classList.add('d-none')
    }
  }

  showSuccess(message) {
    this.showToast(message, 'success')
  }

  showError(message) {
    this.showToast(message, 'error')
  }

  showToast(message, type = 'info') {
    // Create toast notification
    const toastContainer = this.getOrCreateToastContainer()

    const toast = document.createElement('div')
    toast.className = `toast align-items-center text-white bg-${type === 'success' ? 'success' : 'danger'} border-0`
    toast.setAttribute('role', 'alert')
    toast.innerHTML = `
      <div class="d-flex">
        <div class="toast-body">
          <i class="bi bi-${type === 'success' ? 'check-circle' : 'exclamation-triangle'} me-2"></i>
          ${message}
        </div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    `

    toastContainer.appendChild(toast)

    // Initialize and show toast
    const bsToast = new bootstrap.Toast(toast, { delay: 3000 })
    bsToast.show()

    // Clean up after toast is hidden
    toast.addEventListener('hidden.bs.toast', () => {
      toast.remove()
    })
  }

  getOrCreateToastContainer() {
    let container = document.getElementById('toast-container')

    if (!container) {
      container = document.createElement('div')
      container.id = 'toast-container'
      container.className = 'toast-container position-fixed top-0 end-0 p-3'
      container.style.zIndex = '9999'
      document.body.appendChild(container)
    }

    return container
  }
}