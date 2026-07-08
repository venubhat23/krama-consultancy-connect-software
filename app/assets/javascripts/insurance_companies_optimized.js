/**
 * Optimized Insurance Companies Frontend
 * Provides fast AJAX-based interactions for better performance
 */

class InsuranceCompaniesOptimized {
  constructor() {
    this.cache = new Map();
    this.searchTimeout = null;
    this.currentRequest = null;
    this.init();
  }

  init() {
    this.bindEvents();
    this.loadCachedStatistics();
  }

  bindEvents() {
    // Optimized search with debouncing and caching
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => this.handleSearch(e));
      searchInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          this.performSearch(e.target.value);
        }
      });
    }

    // Tab switching with AJAX
    document.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', (e) => this.handleTabSwitch(e));
    });

    // Optimized delete with confirmation
    document.addEventListener('click', (e) => {
      if (e.target.closest('.delete-company')) {
        this.handleDelete(e);
      }
    });

    // Auto-refresh statistics periodically
    setInterval(() => this.refreshStatistics(), 60000); // Every minute
  }

  // Optimized search with caching and debouncing
  handleSearch(event) {
    const query = event.target.value.trim();

    // Clear previous timeout
    clearTimeout(this.searchTimeout);

    // Cancel previous request if still running
    if (this.currentRequest) {
      this.currentRequest.abort();
    }

    // Check cache first
    const cacheKey = this.getCacheKey(query);
    if (this.cache.has(cacheKey)) {
      this.displayResults(this.cache.get(cacheKey));
      return;
    }

    // Debounce the search
    this.searchTimeout = setTimeout(() => {
      this.performSearch(query);
    }, 300); // Reduced from 500ms to 300ms for faster response
  }

  async performSearch(query) {
    try {
      this.showLoadingState();

      const currentTab = this.getCurrentTab();
      const url = new URL('/admin/insurance_companies/search', window.location.origin);

      // Add parameters
      if (query) url.searchParams.append('search', query);
      if (currentTab !== 'all') url.searchParams.append('tab', currentTab);

      this.currentRequest = fetch(url, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      });

      const response = await this.currentRequest;
      const data = await response.json();

      // Cache the results
      const cacheKey = this.getCacheKey(query);
      this.cache.set(cacheKey, data);

      this.displayResults(data);
      this.hideLoadingState();

    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Search error:', error);
        this.showError('Search failed. Please try again.');
      }
    } finally {
      this.currentRequest = null;
    }
  }

  async handleTabSwitch(event) {
    event.preventDefault();

    const link = event.target.closest('.nav-link');
    const tab = new URL(link.href).searchParams.get('tab') || 'all';

    // Update active tab
    document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
    link.classList.add('active');

    // Update URL without page reload
    const url = new URL(window.location);
    url.searchParams.set('tab', tab);
    window.history.pushState(null, '', url);

    // Perform search with new tab
    const searchQuery = document.getElementById('searchInput')?.value || '';
    await this.performSearch(searchQuery);
  }

  async refreshStatistics() {
    try {
      const response = await fetch('/admin/insurance_companies/statistics', {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      });

      const stats = await response.json();
      this.updateStatisticsCards(stats);

    } catch (error) {
      console.error('Statistics refresh failed:', error);
    }
  }

  async loadCachedStatistics() {
    // Load statistics on page load
    await this.refreshStatistics();
  }

  updateStatisticsCards(stats) {
    const cards = {
      total: document.querySelector('[data-stat="total"] h4'),
      life: document.querySelector('[data-stat="life"] h4'),
      health: document.querySelector('[data-stat="health"] h4'),
      motor: document.querySelector('[data-stat="motor"] h4')
    };

    if (cards.total) cards.total.textContent = stats.total || 0;
    if (cards.life) cards.life.textContent = stats.life || 0;
    if (cards.health) cards.health.textContent = stats.health || 0;
    if (cards.motor) cards.motor.textContent = stats.motor_other || 0;

    // Update badge counts in tabs
    document.querySelectorAll('.badge').forEach(badge => {
      const parent = badge.closest('.nav-link');
      if (parent?.href?.includes('tab=life')) badge.textContent = stats.life || 0;
      if (parent?.href?.includes('tab=health')) badge.textContent = stats.health || 0;
      if (parent?.href?.includes('tab=general')) badge.textContent = stats.motor_other || 0;
      if (parent?.href?.includes('tab=all')) badge.textContent = stats.total || 0;
    });
  }

  displayResults(data) {
    const tbody = document.querySelector('tbody');
    if (!tbody) return;

    if (!data.companies || data.companies.length === 0) {
      this.showEmptyState();
      return;
    }

    tbody.innerHTML = data.companies.map(company => this.renderCompanyRow(company)).join('');
    this.bindRowEvents();
  }

  renderCompanyRow(company) {
    const typeInfo = this.getTypeInfo(company.insurance_type);
    const statusInfo = this.getStatusInfo(company.status);

    return `
      <tr data-company-id="${company.id}">
        <td class="align-middle">
          <div class="d-flex align-items-center">
            <div class="avatar-sm bg-primary-subtle rounded-circle d-flex align-items-center justify-content-center me-3">
              <i class="bi bi-building text-primary"></i>
            </div>
            <div>
              <h6 class="mb-0">${this.escapeHtml(company.name)}</h6>
              <small class="text-muted">ID: #${company.id}</small>
            </div>
          </div>
        </td>
        <td class="align-middle">
          <span class="badge ${typeInfo.class}">
            <i class="bi ${typeInfo.icon} me-1"></i>
            ${typeInfo.text}
          </span>
        </td>
        <td class="align-middle">
          <span class="badge bg-secondary-subtle text-secondary">
            ${company.code || 'N/A'}
          </span>
        </td>
        <td class="align-middle">
          <span class="badge ${statusInfo.class}">
            <i class="bi ${statusInfo.icon} me-1"></i>
            ${statusInfo.text}
          </span>
        </td>
        <td class="align-middle">
          ${this.renderActionDropdown(company)}
        </td>
      </tr>
    `;
  }

  renderActionDropdown(company) {
    return `
      <div class="dropdown">
        <button class="btn btn-sm btn-outline-secondary dropdown-toggle" type="button" data-bs-toggle="dropdown">
          <i class="bi bi-three-dots"></i>
        </button>
        <ul class="dropdown-menu">
          <li>
            <a href="/admin/insurance_companies/${company.id}" class="dropdown-item">
              <i class="bi bi-eye me-2"></i> View Details
            </a>
          </li>
          <li>
            <a href="/admin/insurance_companies/${company.id}/edit" class="dropdown-item">
              <i class="bi bi-pencil me-2"></i> Edit Company
            </a>
          </li>
          <li><hr class="dropdown-divider"></li>
          <li>
            <button type="button"
                    class="dropdown-item text-danger delete-company"
                    data-company-id="${company.id}"
                    data-company-name="${this.escapeHtml(company.name)}">
              <i class="bi bi-trash me-2"></i> Delete Company
            </button>
          </li>
        </ul>
      </div>
    `;
  }

  async handleDelete(event) {
    event.preventDefault();

    const button = event.target.closest('.delete-company');
    const companyId = button.dataset.companyId;
    const companyName = button.dataset.companyName;

    if (!confirm(`Are you sure you want to delete ${companyName}? This action cannot be undone.`)) {
      return;
    }

    try {
      this.showLoadingState();

      const response = await fetch(`/admin/insurance_companies/${companyId}`, {
        method: 'DELETE',
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.getCSRFToken()
        }
      });

      if (response.ok) {
        // Remove row from table
        const row = button.closest('tr');
        row.remove();

        // Refresh statistics
        await this.refreshStatistics();

        this.showSuccess(`${companyName} was successfully deleted.`);
      } else {
        const errorData = await response.json();
        this.showError(errorData.error || 'Delete failed. Please try again.');
      }

    } catch (error) {
      console.error('Delete error:', error);
      this.showError('Delete failed. Please try again.');
    } finally {
      this.hideLoadingState();
    }
  }

  // Helper methods
  getCacheKey(query) {
    const tab = this.getCurrentTab();
    return `search-${tab}-${query || 'empty'}`;
  }

  getCurrentTab() {
    const activeTab = document.querySelector('.nav-link.active');
    if (!activeTab) return 'all';

    const url = new URL(activeTab.href);
    return url.searchParams.get('tab') || 'all';
  }

  getTypeInfo(type) {
    const types = {
      'life': { class: 'bg-success-subtle text-success', icon: 'bi-heart-pulse', text: 'Life' },
      'health': { class: 'bg-info-subtle text-info', icon: 'bi-shield-plus', text: 'Health' },
      'motor_other': { class: 'bg-warning-subtle text-warning', icon: 'bi-shield-check', text: 'Motor & Other' }
    };
    return types[type] || { class: 'bg-secondary-subtle text-secondary', icon: 'bi-question', text: 'Unknown' };
  }

  getStatusInfo(status) {
    return status ?
      { class: 'bg-success-subtle text-success', icon: 'bi-check-circle', text: 'Active' } :
      { class: 'bg-danger-subtle text-danger', icon: 'bi-x-circle', text: 'Inactive' };
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]');
    return token ? token.content : '';
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  showLoadingState() {
    const tbody = document.querySelector('tbody');
    if (tbody) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center py-4"><i class="bi bi-spinner-border"></i> Loading...</td></tr>';
    }
  }

  hideLoadingState() {
    // Loading state is automatically hidden when results are displayed
  }

  showEmptyState() {
    const tbody = document.querySelector('tbody');
    if (tbody) {
      tbody.innerHTML = `
        <tr>
          <td colspan="5" class="text-center py-5">
            <div class="mb-3">
              <i class="bi bi-building fs-1 text-muted"></i>
            </div>
            <h5 class="text-muted mb-3">No Insurance Companies Found</h5>
            <p class="text-muted mb-4">Try adjusting your search criteria or add a new company.</p>
          </td>
        </tr>
      `;
    }
  }

  showSuccess(message) {
    this.showAlert(message, 'success');
  }

  showError(message) {
    this.showAlert(message, 'danger');
  }

  showAlert(message, type) {
    // Create alert element
    const alert = document.createElement('div');
    alert.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    alert.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
    alert.innerHTML = `
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;

    document.body.appendChild(alert);

    // Auto-remove after 5 seconds
    setTimeout(() => {
      alert.remove();
    }, 5000);
  }

  bindRowEvents() {
    // Re-bind any row-specific events after table update
    // This is called after displaying new results
  }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  if (document.body.dataset.controller === 'insurance_companies' &&
      document.body.dataset.action === 'index') {
    new InsuranceCompaniesOptimized();
  }
});