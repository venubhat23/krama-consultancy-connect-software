import { Controller } from "@hotwired/stimulus"

// Debounced member search + business-profile preview for the "Refer" form.
// Renders results from a small JSON endpoint without any external dependency.
export default class extends Controller {
  static targets = ["query", "results", "selectedId", "profile", "submit"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  search() {
    clearTimeout(this.timeout)
    const query = this.queryTarget.value.trim()
    this.selectedIdTarget.value = ""
    this.submitTarget.disabled = true
    this.timeout = setTimeout(() => this.performSearch(query), 250)
  }

  async performSearch(query) {
    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      return
    }

    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
    const members = await response.json()
    this.renderResults(members)
  }

  renderResults(members) {
    if (members.length === 0) {
      this.resultsTarget.innerHTML = `<div class="list-group-item text-muted">No members found</div>`
      return
    }

    this.resultsTarget.innerHTML = members.map((m, i) => {
      const subtitle = m.company_name
        ? `<br><small class="text-muted">${this.escape(m.company_name)}${m.designation ? " — " + this.escape(m.designation) : ""}</small>`
        : ""
      return `<button type="button" class="list-group-item list-group-item-action" data-index="${i}" data-action="click->member-search#select">
        <strong>${this.escape(m.name)}</strong> ${m.chapter ? `<span class="text-muted">· ${this.escape(m.chapter)}</span>` : ""}
        ${subtitle}
      </button>`
    }).join("")

    this.lastResults = members
  }

  select(event) {
    const member = this.lastResults[Number(event.currentTarget.dataset.index)]
    this.selectedIdTarget.value = member.id
    this.queryTarget.value = member.name
    this.resultsTarget.innerHTML = ""
    this.renderProfile(member)
    this.submitTarget.disabled = false
  }

  renderProfile(member) {
    const rows = []
    if (member.chapter) rows.push(["Chapter", member.chapter])
    if (member.company_name) rows.push(["Company", member.company_name])
    if (member.designation) rows.push(["Designation", member.designation])
    if (member.business_category) rows.push(["Category", member.business_category])
    if (member.speciality) rows.push(["Speciality", member.speciality])
    if (member.nature_of_business) rows.push(["Nature of Business", member.nature_of_business])
    if (member.mobile) rows.push(["Mobile", member.mobile])

    if (rows.length === 0) {
      this.profileTarget.innerHTML = `<div class="text-muted small">No business info on file for ${this.escape(member.name)} yet.</div>`
      return
    }

    const rowsHtml = rows.map(([label, value]) =>
      `<div class="d-flex justify-content-between small mb-1"><span class="text-muted">${this.escape(label)}</span><span class="fw-medium">${this.escape(String(value))}</span></div>`
    ).join("")

    this.profileTarget.innerHTML = `
      <div class="card border-0 bg-light">
        <div class="card-body">
          <h6 class="mb-2">${this.escape(member.name)}'s Business Profile</h6>
          ${rowsHtml}
        </div>
      </div>
    `
  }

  escape(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
