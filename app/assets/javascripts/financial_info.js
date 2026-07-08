// Financial Information Expandable Sections JavaScript

document.addEventListener('DOMContentLoaded', function() {
  // Handle collapse/expand for all financial info sections
  const sectionHeaders = document.querySelectorAll('.financial-info-container .section-header');

  sectionHeaders.forEach(function(header) {
    const chevronIcon = header.querySelector('.collapse-icon');
    const targetId = header.getAttribute('data-bs-target');
    const targetElement = document.querySelector(targetId);

    if (targetElement && chevronIcon) {
      // Handle Bootstrap collapse events
      targetElement.addEventListener('show.bs.collapse', function() {
        header.classList.remove('collapsed');
        chevronIcon.classList.remove('bi-chevron-down');
        chevronIcon.classList.add('bi-chevron-up');

        // Add animation class
        header.classList.add('expanding');
        setTimeout(() => header.classList.remove('expanding'), 300);
      });

      targetElement.addEventListener('hide.bs.collapse', function() {
        header.classList.add('collapsed');
        chevronIcon.classList.remove('bi-chevron-up');
        chevronIcon.classList.add('bi-chevron-down');

        // Add animation class
        header.classList.add('collapsing-custom');
        setTimeout(() => header.classList.remove('collapsing-custom'), 300);
      });
    }
  });

  // Add expand all / collapse all functionality
  addExpandCollapseAllButtons();
});

function addExpandCollapseAllButtons() {
  const container = document.querySelector('.financial-info-container');
  if (!container) return;

  // Create control buttons container
  const controlsDiv = document.createElement('div');
  controlsDiv.className = 'financial-info-controls mb-3 d-flex gap-2';
  controlsDiv.innerHTML = `
    <button type="button" class="btn btn-outline-primary btn-sm" id="expandAllFinancial">
      <i class="bi bi-arrows-expand me-1"></i>Expand All
    </button>
    <button type="button" class="btn btn-outline-secondary btn-sm" id="collapseAllFinancial">
      <i class="bi bi-arrows-collapse me-1"></i>Collapse All
    </button>
  `;

  // Insert controls at the beginning of the container
  container.insertBefore(controlsDiv, container.firstChild);

  // Add event listeners for expand/collapse all
  document.getElementById('expandAllFinancial').addEventListener('click', function() {
    const allCollapseElements = container.querySelectorAll('[id$="Collapse"]');
    allCollapseElements.forEach(function(element) {
      const bsCollapse = new bootstrap.Collapse(element, {show: true});
    });
  });

  document.getElementById('collapseAllFinancial').addEventListener('click', function() {
    const allCollapseElements = container.querySelectorAll('[id$="Collapse"]');
    allCollapseElements.forEach(function(element) {
      const bsCollapse = new bootstrap.Collapse(element, {hide: true});
    });
  });
}

// Utility function to format currency if needed
function formatIndianCurrency(amount) {
  if (!amount || isNaN(amount)) return '₹0';

  const formatter = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
  });

  return formatter.format(amount);
}

// Animation helper functions
function addSmoothTransition(element) {
  element.style.transition = 'all 0.3s ease-in-out';
}

// Add hover effects for better user experience
document.addEventListener('DOMContentLoaded', function() {
  const sectionHeaders = document.querySelectorAll('.financial-info-container .section-header');

  sectionHeaders.forEach(function(header) {
    header.addEventListener('mouseenter', function() {
      this.style.backgroundColor = '#f8f9fa';
      this.style.cursor = 'pointer';
    });

    header.addEventListener('mouseleave', function() {
      this.style.backgroundColor = '';
    });
  });
});