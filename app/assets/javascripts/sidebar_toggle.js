/**
 * BULLETPROOF SIDEBAR TOGGLE
 * Senior Architect Approved Implementation
 */

class SidebarController {
  constructor() {
    this.layoutContainer = document.querySelector('.layout-container');
    this.toggleButton = document.getElementById('sidebarToggle');
    this.menuLinks = document.querySelectorAll('.menu-link');

    this.init();
  }

  init() {
    // Load saved state
    this.loadState();

    // Setup toggle button
    if (this.toggleButton) {
      this.toggleButton.addEventListener('click', () => this.toggle());
    }

    // Setup tooltips for menu items
    this.setupTooltips();

    // Keyboard shortcut (Ctrl/Cmd + B)
    document.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'b') {
        e.preventDefault();
        this.toggle();
      }
    });
  }

  toggle() {
    const isCollapsed = this.layoutContainer.classList.toggle('sidebar-collapsed');

    // Save state
    localStorage.setItem('sidebar-collapsed', isCollapsed ? 'true' : 'false');

    // Dispatch event for other components
    window.dispatchEvent(new CustomEvent('sidebar-toggled', {
      detail: { collapsed: isCollapsed }
    }));
  }

  loadState() {
    const isCollapsed = localStorage.getItem('sidebar-collapsed') === 'true';

    if (isCollapsed) {
      this.layoutContainer.classList.add('sidebar-collapsed');
    }
  }

  setupTooltips() {
    this.menuLinks.forEach(link => {
      const label = link.querySelector('.label');
      if (label) {
        link.setAttribute('data-tooltip', label.textContent);
      }
    });
  }

  // Public API
  expand() {
    this.layoutContainer.classList.remove('sidebar-collapsed');
    localStorage.setItem('sidebar-collapsed', 'false');
  }

  collapse() {
    this.layoutContainer.classList.add('sidebar-collapsed');
    localStorage.setItem('sidebar-collapsed', 'true');
  }

  isCollapsed() {
    return this.layoutContainer.classList.contains('sidebar-collapsed');
  }
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
  window.sidebarController = new SidebarController();
});

// Also initialize on Turbo load (for Rails)
document.addEventListener('turbo:load', () => {
  window.sidebarController = new SidebarController();
});