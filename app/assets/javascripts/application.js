// Modern Drwise Admin JavaScript

// Global app object
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

  // Navigation functionality
  initNavigation() {
    const navItems = document.querySelectorAll('.nav-link');

    navItems.forEach(item => {
      item.addEventListener('click', (e) => {
        // Add loading state to clicked nav item
        const icon = item.querySelector('.nav-icon i');
        if (icon) {
          const originalIcon = icon.className;
          icon.className = 'loading-spinner';

          // Restore icon after a short delay
          setTimeout(() => {
            icon.className = originalIcon;
          }, 1000);
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

// Add ripple animation keyframes
const style = document.createElement('style');
style.textContent = `
  @keyframes ripple {
    to {
      transform: scale(4);
      opacity: 0;
    }
  }
`;
document.head.appendChild(style);

// Dark mode toggle (future feature)
function toggleDarkMode() {
  document.body.classList.toggle('dark-mode');
  const isDark = document.body.classList.contains('dark-mode');
  localStorage.setItem('darkMode', isDark);
}

// Load dark mode preference
if (localStorage.getItem('darkMode') === 'true') {
  document.body.classList.add('dark-mode');
}