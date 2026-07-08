/**
 * Form Enhancement Library
 * Provides reusable form validation and enhancement functionality
 */

window.FormEnhancements = (function() {
  'use strict';

  // Mobile number validation: only allow numbers, spaces, +, -, (, )
  function enhanceMobileFields() {
    const mobileFields = document.querySelectorAll(
      'input[type="tel"], input[name*="mobile"], input[name*="contact_number"], input[name*="phone"]'
    );

    mobileFields.forEach(function(field) {
      // Only allow numbers and specific characters during input
      field.addEventListener('input', function(e) {
        let value = e.target.value;

        // Remove all characters except numbers, spaces, +, -, (, )
        value = value.replace(/[^0-9\s\+\-\(\)]/g, '');

        // Limit to reasonable length (15 digits max for international numbers)
        const digitsOnly = value.replace(/\D/g, '');
        if (digitsOnly.length > 15) {
          value = value.substring(0, value.length - (digitsOnly.length - 15));
        }

        e.target.value = value;
      });

      // Prevent non-numeric characters on keypress
      field.addEventListener('keypress', function(e) {
        const allowedChars = /[0-9\s\+\-\(\)]/;
        const char = String.fromCharCode(e.which);

        // Allow backspace, delete, tab, escape, enter
        if ([8, 9, 27, 13, 46].indexOf(e.which) !== -1 ||
            // Allow Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X
            (e.which === 65 && e.ctrlKey === true) ||
            (e.which === 67 && e.ctrlKey === true) ||
            (e.which === 86 && e.ctrlKey === true) ||
            (e.which === 88 && e.ctrlKey === true)) {
          return;
        }

        // Only allow specific characters
        if (!allowedChars.test(char)) {
          e.preventDefault();
        }
      });

      // Format on blur (when user finishes editing) - DISABLED FOR DISTRIBUTORS AND INVESTORS
      field.addEventListener('blur', function(e) {
        // Skip formatting for forms that have their own mobile validation handling
        const form = e.target.closest('form');
        const isDistributorForm = form?.action?.includes('distributors');
        const isInvestorForm = form?.action?.includes('investors');
        const isCustomerForm = form?.action?.includes('customers');
        const isLeadForm = form?.action?.includes('leads');
        if (isDistributorForm || isInvestorForm || isCustomerForm || isLeadForm) {
          return;
        }

        let value = e.target.value.trim();
        const digitsOnly = value.replace(/\D/g, '');

        // Format Indian mobile numbers (10 digits starting with 6, 7, 8, or 9)
        if (digitsOnly.length === 10 && /^[6789]/.test(digitsOnly)) {
          e.target.value = '+91 ' + digitsOnly.substring(0, 5) + ' ' + digitsOnly.substring(5);
        } else if (digitsOnly.length === 12 && digitsOnly.startsWith('91')) {
          // Handle numbers with country code (12 digits total: 91 + 10 digit mobile)
          const number = digitsOnly.substring(2);
          if (number.length === 10 && /^[6789]/.test(number)) {
            e.target.value = '+91 ' + number.substring(0, 5) + ' ' + number.substring(5);
          }
        }
      });

      // Add visual feedback
      field.addEventListener('focus', function(e) {
        e.target.classList.add('mobile-field-active');
      });

      field.addEventListener('blur', function(e) {
        e.target.classList.remove('mobile-field-active');
      });
    });
  }

  // State-City dropdown dependency
  function enhanceStateCityDropdowns() {
    const stateSelects = document.querySelectorAll(
      'select[name*="state"], #lead_state, #customer_state_individual, #customer_state_corporate'
    );

    stateSelects.forEach(function(stateSelect) {
      const stateId = stateSelect.id;
      const baseName = stateId.replace('_state', '');

      // Find corresponding city dropdown
      let citySelect = document.getElementById(baseName + '_city');

      // Fallback searches for common city field patterns
      if (!citySelect) {
        const possibleCityIds = [
          stateId.replace('state', 'city'),
          stateId.replace('_state', '_city'),
          'city' // generic fallback
        ];

        for (let cityId of possibleCityIds) {
          citySelect = document.getElementById(cityId);
          if (citySelect) break;
        }
      }

      // Also try to find by proximity in DOM
      if (!citySelect) {
        const container = stateSelect.closest('.row') || stateSelect.closest('.card-body');
        if (container) {
          citySelect = container.querySelector('select[name*="city"]');
        }
      }

      if (citySelect) {
        setupStateCityDependency(stateSelect, citySelect);
      }
    });
  }

  function setupStateCityDependency(stateSelect, citySelect) {
    stateSelect.addEventListener('change', function() {
      loadCitiesForState(this.value, citySelect);
    });

    // Load cities if state is pre-selected
    if (stateSelect.value) {
      loadCitiesForState(stateSelect.value, citySelect);
    }
  }

  function loadCitiesForState(stateValue, citySelect) {
    if (!stateValue) {
      citySelect.innerHTML = '<option value="">Select State First</option>';
      citySelect.disabled = true;
      return;
    }

    // Show loading state
    citySelect.innerHTML = '<option value="">Loading cities...</option>';
    citySelect.disabled = true;

    // Use global location data if available, otherwise API
    if (window.LocationData && window.LocationData.states && window.LocationData.states[stateValue]) {
      const cities = window.LocationData.states[stateValue].cities || [];
      populateCityDropdown(cities, citySelect);
    } else {
      // Fallback to API call
      fetch(`/api/cities?state=${encodeURIComponent(stateValue)}`)
        .then(response => {
          if (!response.ok) throw new Error('Network response was not ok');
          return response.json();
        })
        .then(data => {
          const cities = data.cities || [];
          populateCityDropdown(cities, citySelect);
        })
        .catch(error => {
          console.error('Error loading cities:', error);
          citySelect.innerHTML = '<option value="">Error loading cities</option>';
          citySelect.disabled = true;
        });
    }
  }

  function populateCityDropdown(cities, citySelect) {
    // Clear and populate dropdown
    citySelect.innerHTML = '<option value="">Select City</option>';

    cities.forEach(city => {
      const option = document.createElement('option');
      option.value = city;
      option.textContent = city;
      citySelect.appendChild(option);
    });

    citySelect.disabled = false;
  }

  // Enhanced form validation
  function enhanceFormValidation() {
    const forms = document.querySelectorAll('.needs-validation');

    forms.forEach(function(form) {
      // Real-time validation for common fields
      const mobileFields = form.querySelectorAll('input[name*="mobile"], input[name*="contact_number"]');
      mobileFields.forEach(function(field) {
        field.addEventListener('blur', function() {
          validateMobileField(this);
        });
      });

      // Email validation
      const emailFields = form.querySelectorAll('input[type="email"]');
      emailFields.forEach(function(field) {
        field.addEventListener('blur', function() {
          validateEmailField(this);
        });
      });

      // Form submission validation
      form.addEventListener('submit', function(e) {
        // Strip +91/91/0 prefix from mobile/contact fields before HTML5 pattern check
        form.querySelectorAll('input[name*="mobile"], input[name*="contact_number"]').forEach(function(field) {
          let v = field.value.replace(/\D/g, '');
          if (v.length === 12 && v.startsWith('91')) v = v.slice(2);
          else if (v.length === 13 && v.startsWith('91')) v = v.slice(2);
          else if (v.length === 11 && v.startsWith('0')) v = v.slice(1);
          field.value = v;
        });

        if (!form.checkValidity()) {
          e.preventDefault();
          e.stopPropagation();
          showValidationErrors(form);
        }
        form.classList.add('was-validated');
      });
    });
  }

  function validateMobileField(field) {
    const value = field.value.trim();
    const digitsOnly = value.replace(/\D/g, '');

    if (field.hasAttribute('required') && !value) {
      showFieldError(field, 'Mobile number is required');
      return false;
    }

    if (value && digitsOnly.length < 10) {
      showFieldError(field, 'Please enter a valid 10-digit mobile number');
      return false;
    }

    if (value && digitsOnly.length > 0 && digitsOnly.length < 10) {
      showFieldError(field, 'Mobile number must be at least 10 digits');
      return false;
    }

    clearFieldError(field);
    return true;
  }

  function validateEmailField(field) {
    const value = field.value.trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (field.hasAttribute('required') && !value) {
      showFieldError(field, 'Email is required');
      return false;
    }

    if (value && !emailRegex.test(value)) {
      showFieldError(field, 'Please enter a valid email address');
      return false;
    }

    clearFieldError(field);
    return true;
  }

  function showFieldError(field, message) {
    field.classList.add('is-invalid');
    field.classList.remove('is-valid');

    // Show error message
    let feedback = field.parentNode.querySelector('.invalid-feedback');
    if (!feedback) {
      feedback = document.createElement('div');
      feedback.className = 'invalid-feedback';
      field.parentNode.appendChild(feedback);
    }
    feedback.textContent = message;
  }

  function clearFieldError(field) {
    field.classList.remove('is-invalid');
    field.classList.add('is-valid');
  }

  function showValidationErrors(form) {
    const invalidFields = form.querySelectorAll(':invalid');
    if (invalidFields.length > 0) {
      // Focus on first invalid field
      invalidFields[0].focus();

      // Show alert with error summary
      const errorMessages = Array.from(invalidFields).map(field => {
        const label = form.querySelector(`label[for="${field.id}"]`);
        const fieldName = label ? label.textContent.replace(' *', '') : field.name;
        return `• ${fieldName} is required or invalid`;
      });

      if (errorMessages.length > 0) {
        const alertDiv = document.createElement('div');
        alertDiv.className = 'alert alert-danger alert-dismissible fade show mt-3';
        alertDiv.innerHTML = `
          <strong>Please correct the following errors:</strong>
          <ul class="mb-0 mt-2">
            ${errorMessages.map(msg => `<li>${msg}</li>`).join('')}
          </ul>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;

        // Insert at top of form
        form.insertBefore(alertDiv, form.firstChild);

        // Auto-remove after 5 seconds
        setTimeout(() => {
          if (alertDiv.parentNode) {
            alertDiv.remove();
          }
        }, 5000);
      }
    }
  }

  // Add CSS styles for enhanced mobile fields
  function addEnhancementStyles() {
    if (document.getElementById('form-enhancement-styles')) return;

    const style = document.createElement('style');
    style.id = 'form-enhancement-styles';
    style.textContent = `
      .mobile-field-active {
        border-color: #0d6efd !important;
        box-shadow: 0 0 0 0.2rem rgba(13, 110, 253, 0.25) !important;
      }

      .form-control.is-valid {
        border-color: #198754;
        background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 8 8'%3e%3cpath fill='%23198754' d='m2.3 6.73.6-.6 3.8-3.8.6-.6L8 1.7l-.6.6L3.9 5.8l-1.6-1.6L1.7 3.6l.6.6z'/%3e%3c/svg%3e");
        background-repeat: no-repeat;
        background-position: right calc(0.375em + 0.1875rem) center;
        background-size: calc(0.75em + 0.375rem) calc(0.75em + 0.375rem);
      }

      .form-control.is-invalid {
        border-color: #dc3545;
        background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12' width='12' height='12' fill='none' stroke='%23dc3545'%3e%3ccircle cx='6' cy='6' r='4.5'/%3e%3cpath d='m5.8 4.6 4.8 4.8 M4.2 7.4l4.8-4.8'/%3e%3c/svg%3e");
        background-repeat: no-repeat;
        background-position: right calc(0.375em + 0.1875rem) center;
        background-size: calc(0.75em + 0.375rem) calc(0.75em + 0.375rem);
      }

      .invalid-feedback {
        display: block;
        width: 100%;
        margin-top: 0.25rem;
        font-size: 0.875em;
        color: #dc3545;
      }

      .valid-feedback {
        display: block;
        width: 100%;
        margin-top: 0.25rem;
        font-size: 0.875em;
        color: #198754;
      }
    `;

    document.head.appendChild(style);
  }

  // Initialize all enhancements
  function init() {
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function() {
        initializeEnhancements();
      });
    } else {
      initializeEnhancements();
    }
  }

  function initializeEnhancements() {
    addEnhancementStyles();
    enhanceMobileFields();
    enhanceStateCityDropdowns();
    enhanceFormValidation();
  }

  // Public API
  return {
    init: init,
    enhanceMobileFields: enhanceMobileFields,
    enhanceStateCityDropdowns: enhanceStateCityDropdowns,
    enhanceFormValidation: enhanceFormValidation,
    validateMobileField: validateMobileField,
    validateEmailField: validateEmailField,
    loadCitiesForState: loadCitiesForState
  };
})();

// Auto-initialize when script loads
FormEnhancements.init();