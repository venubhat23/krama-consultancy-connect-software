import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = ["menuItem", "submenu", "chevron"]

  connect() {
    console.log("Sidebar controller connected")
    this.initializeActiveStates()
    this.initializeScrollPosition()
    this.setupScrollSaving()
  }

  initializeScrollPosition() {
    // Restore scroll position from sessionStorage
    const savedScrollPosition = sessionStorage.getItem('sidebarScrollPosition')
    if (savedScrollPosition) {
      this.element.scrollTop = parseInt(savedScrollPosition, 10)
    }
  }

  setupScrollSaving() {
    // Save scroll position before navigation
    this.element.addEventListener('scroll', this.saveScrollPosition.bind(this))

    // Save scroll position when clicking on navigation links
    const navLinks = this.element.querySelectorAll('a')
    navLinks.forEach(link => {
      link.addEventListener('click', () => {
        this.saveScrollPosition()
      })
    })

    // Save scroll position before page unload
    window.addEventListener('beforeunload', () => {
      this.saveScrollPosition()
    })

    // Save scroll position on turbo:before-visit
    document.addEventListener('turbo:before-visit', () => {
      this.saveScrollPosition()
    })

    // Restore scroll position after turbo navigation
    document.addEventListener('turbo:load', () => {
      this.restoreScrollPosition()
    })
  }

  saveScrollPosition() {
    const scrollPosition = this.element.scrollTop
    sessionStorage.setItem('sidebarScrollPosition', scrollPosition.toString())
  }

  restoreScrollPosition() {
    const savedScrollPosition = sessionStorage.getItem('sidebarScrollPosition')
    if (savedScrollPosition) {
      // Use setTimeout to ensure DOM is fully rendered
      setTimeout(() => {
        this.element.scrollTop = parseInt(savedScrollPosition, 10)
      }, 50)
    }
  }

  toggleSubmenu(event) {
    event.preventDefault()
    const menuItem = event.currentTarget.closest('[data-sidebar-target="menuItem"]')
    const submenu = menuItem.querySelector('[data-sidebar-target="submenu"]')
    const chevron = menuItem.querySelector('[data-sidebar-target="chevron"]')

    if (submenu) {
      if (submenu.classList.contains('hidden')) {
        // Show submenu
        submenu.classList.remove('hidden')
        submenu.classList.add('animate-slide-down')
        chevron.style.transform = 'rotate(180deg)'
      } else {
        // Hide submenu
        submenu.classList.add('hidden')
        submenu.classList.remove('animate-slide-down')
        chevron.style.transform = 'rotate(0deg)'
      }
    }
  }

  initializeActiveStates() {
    // Set active state based on current URL
    const currentPath = window.location.pathname
    this.menuItemTargets.forEach(item => {
      const link = item.querySelector('a')
      if (link && link.getAttribute('href') === currentPath) {
        item.classList.add('menu-item-active')
        item.classList.remove('text-blue-200')

        // If this item has a parent submenu, open it
        const parentSubmenu = item.closest('[data-sidebar-target="submenu"]')
        if (parentSubmenu) {
          parentSubmenu.classList.remove('hidden')
          const parentChevron = parentSubmenu.previousElementSibling.querySelector('[data-sidebar-target="chevron"]')
          if (parentChevron) {
            parentChevron.style.transform = 'rotate(180deg)'
          }
        }
      }
    })
  }
}