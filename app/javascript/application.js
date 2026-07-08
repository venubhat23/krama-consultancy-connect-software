// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"
import "dynamic_insurance_dropdowns"

// Premium Drwise Admin JavaScript
window.KramaConsBusinessForum = {

  // Initialize the application
  init() {
    this.initSidebar();
    this.initAnimations();
    this.initTooltips();
  },

  // Sidebar functionality
  initSidebar() {
    const sidebar = document.getElementById('sidebar');
    if (!sidebar) return;

    // Auto-hide sidebar backdrop on window resize
    window.addEventListener('resize', () => {
      if (window.innerWidth >= 992) {
        sidebar.classList.remove('show');
        this.removeBackdrop();
      }
    });

    // Initialize navigation item clicks
    this.initNavigation();
  },

  // Navigation functionality with collapsible support
  initNavigation() {
    // Handle collapsible navigation items
    const collapseButtons = document.querySelectorAll('[data-bs-toggle="collapse"]');
    collapseButtons.forEach(button => {
      button.addEventListener('click', function(e) {
        e.preventDefault();

        const target = document.querySelector(this.getAttribute('data-bs-target'));
        if (target) {
          // Initialize Bootstrap collapse if not already initialized
          let bsCollapse = bootstrap.Collapse.getInstance(target);
          if (!bsCollapse) {
            bsCollapse = new bootstrap.Collapse(target, { toggle: false });
          }

          // Toggle the collapse
          bsCollapse.toggle();

          // Update button state
          this.classList.toggle('collapsed');
          const isExpanded = !this.classList.contains('collapsed');
          this.setAttribute('aria-expanded', isExpanded);
        }
      });
    });

    // Handle regular navigation clicks
    const navItems = document.querySelectorAll('.nav-link-modern:not([data-bs-toggle="collapse"])');
    navItems.forEach(item => {
      item.addEventListener('click', (e) => {
        // Don't prevent default - allow normal navigation
        // Just add visual feedback

        // Remove active from other nav items
        document.querySelectorAll('.nav-link-modern').forEach(link => {
          link.classList.remove('active');
        });

        // Add active to clicked item
        item.classList.add('active');

        // Add loading state to clicked nav item
        const iconBg = item.querySelector('.icon-bg');
        if (iconBg) {
          const originalIcon = iconBg.querySelector('i');
          if (originalIcon) {
            const originalClass = originalIcon.className;
            originalIcon.className = 'bi bi-arrow-clockwise';
            originalIcon.style.animation = 'spin 1s linear infinite';

            // Restore icon after a short delay
            setTimeout(() => {
              originalIcon.className = originalClass;
              originalIcon.style.animation = '';
            }, 1000);
          }
        }
      });
    });
  },

  // Animation initialization
  initAnimations() {
    // Intersection Observer for fade-in animations
    const observerOptions = {
      threshold: 0.1,
      rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
        }
      });
    }, observerOptions);

    // Observe elements with fade-in class
    document.querySelectorAll('.fade-in').forEach(el => {
      el.style.opacity = '0';
      el.style.transform = 'translateY(20px)';
      el.style.transition = 'opacity 0.6s ease-out, transform 0.6s ease-out';
      observer.observe(el);
    });

    // Stats counter animation
    this.animateCounters();
  },

  // Animate number counters
  animateCounters() {
    const counters = document.querySelectorAll('.stats-number');

    counters.forEach(counter => {
      const target = parseInt(counter.textContent.replace(/[₹,]/g, ''));
      if (isNaN(target)) return;

      let current = 0;
      const increment = target / 60; // 60 frames for 1 second

      const updateCounter = () => {
        if (current < target) {
          current += increment;
          counter.textContent = counter.textContent.includes('₹')
            ? `₹${Math.floor(current).toLocaleString()}`
            : Math.floor(current).toLocaleString();
          requestAnimationFrame(updateCounter);
        } else {
          counter.textContent = counter.textContent.includes('₹')
            ? `₹${target.toLocaleString()}`
            : target.toLocaleString();
        }
      };

      // Trigger animation when element is visible
      const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            updateCounter();
            observer.unobserve(entry.target);
          }
        });
      });

      observer.observe(counter);
    });
  },

  // Initialize Bootstrap tooltips
  initTooltips() {
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
      return new bootstrap.Tooltip(tooltipTriggerEl);
    });
  },

  // Remove backdrop
  removeBackdrop() {
    const backdrop = document.querySelector('.sidebar-backdrop');
    if (backdrop) {
      backdrop.remove();
    }
  }
};

// Global sidebar toggle function
function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  if (sidebar.classList.contains('show')) {
    sidebar.classList.remove('show');
    KramaConsBusinessForum.removeBackdrop();
  } else {
    sidebar.classList.add('show');

    // Create backdrop
    const backdrop = document.createElement('div');
    backdrop.className = 'sidebar-backdrop';
    backdrop.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.5);
      z-index: 999;
      backdrop-filter: blur(4px);
      transition: opacity 0.3s ease;
    `;

    backdrop.onclick = () => toggleSidebar();
    document.body.appendChild(backdrop);

    // Fade in backdrop
    setTimeout(() => {
      backdrop.style.opacity = '1';
    }, 10);
  }
}

// Make it globally available
window.toggleSidebar = toggleSidebar;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  KramaConsBusinessForum.init();
});

// Enhanced dropdown functionality
document.addEventListener('DOMContentLoaded', function() {
  // Notification dropdown enhancements
  const notificationDropdown = document.querySelector('.notification-dropdown');
  if (notificationDropdown) {
    notificationDropdown.addEventListener('shown.bs.dropdown', function() {
      // Mark notifications as seen
      const badge = document.querySelector('.notification-bell .badge');
      if (badge) {
        setTimeout(() => {
          badge.style.opacity = '0';
        }, 2000);
      }
    });
  }

  // Search functionality
  const searchInput = document.querySelector('.search-box input');
  if (searchInput) {
    searchInput.addEventListener('focus', function() {
      this.parentElement.style.transform = 'scale(1.02)';
    });

    searchInput.addEventListener('blur', function() {
      this.parentElement.style.transform = 'scale(1)';
    });
  }

  // Button click effects
  document.querySelectorAll('.btn').forEach(button => {
    button.addEventListener('click', function(e) {
      // Create ripple effect
      const ripple = document.createElement('span');
      const rect = this.getBoundingClientRect();
      const size = Math.max(rect.width, rect.height);
      const x = e.clientX - rect.left - size / 2;
      const y = e.clientY - rect.top - size / 2;

      ripple.style.cssText = `
        position: absolute;
        width: ${size}px;
        height: ${size}px;
        left: ${x}px;
        top: ${y}px;
        background: rgba(255, 255, 255, 0.5);
        border-radius: 50%;
        transform: scale(0);
        animation: ripple 0.6s linear;
        pointer-events: none;
      `;

      this.style.position = 'relative';
      this.style.overflow = 'hidden';
      this.appendChild(ripple);

      setTimeout(() => {
        ripple.remove();
      }, 600);
    });
  });
});

// Add ripple and spin animation keyframes
const style = document.createElement('style');
style.textContent = `
  @keyframes ripple {
    to {
      transform: scale(4);
      opacity: 0;
    }
  }

  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }
`;
document.head.appendChild(style);
