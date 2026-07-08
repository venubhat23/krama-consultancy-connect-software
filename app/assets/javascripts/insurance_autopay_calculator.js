// Insurance Autopay Calculator - Shared functionality for all insurance forms
// This script handles automatic calculation of installment autopay end dates based on payment mode

window.InsuranceAutopayCalculator = {
  // Calculate autopay end date based on payment mode and start date
  calculateAutopayEndDate: function() {
    const paymentModeField = document.getElementById('payment_mode_select') || document.getElementById('payment_mode');
    const startDateField = document.getElementById('autopay_start_date');
    const endDateField = document.getElementById('autopay_end_date');

    if (!paymentModeField || !startDateField || !endDateField) {
      console.log('⚠️ Required fields not found for autopay calculation');
      return;
    }

    const paymentMode = paymentModeField.value;
    const startDate = startDateField.value;

    if (startDate && paymentMode) {
      const start = new Date(startDate);
      let end = new Date(start);

      // Calculate end date based on payment mode
      switch (paymentMode) {
        case 'Yearly':
        case 'Annual':
          end.setFullYear(end.getFullYear() + 1);
          end.setDate(end.getDate() - 1); // Subtract 1 day to make it end on the day before anniversary
          break;
        case 'Half Yearly':
        case 'Half-Yearly':
        case 'Semi-Annual':
          end.setMonth(end.getMonth() + 6);
          end.setDate(end.getDate() - 1);
          break;
        case 'Quarterly':
          end.setMonth(end.getMonth() + 3);
          end.setDate(end.getDate() - 1);
          break;
        case 'Monthly':
          end.setMonth(end.getMonth() + 1);
          end.setDate(end.getDate() - 1);
          break;
        case 'Single':
        case 'One Time':
          // For single payment, autopay end date is the same as start date
          end.setTime(start.getTime());
          break;
        default:
          // Default to yearly if no mode selected
          end.setFullYear(end.getFullYear() + 1);
          end.setDate(end.getDate() - 1);
          break;
      }

      // Set the calculated end date
      endDateField.value = end.toISOString().split('T')[0];
      console.log('✅ Autopay end date calculated:', endDateField.value, 'for payment mode:', paymentMode);
    }
  },

  // Update autopay start date when policy start date changes
  updateAutopayStartDate: function() {
    const policyStartField = document.getElementById('start_date') ||
                             document.getElementById('policy_start_date') ||
                             document.getElementById('motor_insurance_policy_start_date');
    const autopayStartField = document.getElementById('autopay_start_date');

    if (policyStartField && autopayStartField) {
      const policyStartDate = policyStartField.value;
      if (policyStartDate) {
        autopayStartField.value = policyStartDate;
        this.calculateAutopayEndDate(); // Recalculate end date
        console.log('✅ Autopay start date updated to match policy start date:', policyStartDate);
      }
    }
  },

  // Initialize event listeners for autopay calculation
  initializeEventListeners: function() {
    // Payment mode change listener
    const paymentModeField = document.getElementById('payment_mode_select') || document.getElementById('payment_mode');
    if (paymentModeField) {
      paymentModeField.addEventListener('change', () => {
        this.calculateAutopayEndDate();
      });
    }

    // Autopay start date change listener
    const autopayStartDateField = document.getElementById('autopay_start_date');
    if (autopayStartDateField) {
      autopayStartDateField.addEventListener('change', () => {
        this.calculateAutopayEndDate();
      });
    }

    // Policy start date change listener
    const policyStartFields = [
      document.getElementById('start_date'),
      document.getElementById('policy_start_date'),
      document.getElementById('motor_insurance_policy_start_date')
    ];

    policyStartFields.forEach(field => {
      if (field) {
        field.addEventListener('change', () => {
          this.updateAutopayStartDate();
        });
      }
    });

    // Calculate on page load if values exist
    if (autopayStartDateField && autopayStartDateField.value && paymentModeField && paymentModeField.value) {
      this.calculateAutopayEndDate();
    }
  },

  // Initialize the calculator when DOM is ready
  initialize: function() {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => {
        this.initializeEventListeners();
      });
    } else {
      this.initializeEventListeners();
    }
  }
};

// Auto-initialize when the script loads
InsuranceAutopayCalculator.initialize();