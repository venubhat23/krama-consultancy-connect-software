// Dynamic Insurance Dropdowns - Rewritten for exact requirements
// Handles broker code type switching with proper dependent behavior

function initializeDynamicDropdowns() {
  // Prevent double initialization
  if (window.dynamicDropdownsInitialized) {
    console.log('⚠️ Dynamic dropdowns already initialized');
    return;
  }

  console.log('🚀 Initializing Dynamic Dropdowns...');

  // Find form elements
  const brokerCodeSelect = document.getElementById('life_insurance_broker_code_type') ||
                          document.getElementById('health_insurance_broker_code_type');
  const agencyCodeSelect = document.getElementById('life_insurance_agency_code_id') ||
                          document.getElementById('health_insurance_agency_code_id');
  const insuranceCompanySelect = document.getElementById('life_insurance_insurance_company_name') ||
                               document.getElementById('health_insurance_insurance_company_name');
  const agencyCodeLabel = document.querySelector('label[for="' + (agencyCodeSelect ? agencyCodeSelect.id : '') + '"]');

  if (!brokerCodeSelect || !agencyCodeSelect || !insuranceCompanySelect) {
    console.log('❌ Dynamic dropdown elements not found');
    return;
  }

  console.log('✅ Found all dropdown elements');

  // Determine the base URL based on current page
  const currentPath = window.location.pathname;
  const baseUrl = currentPath.includes('/life') ? '/admin/insurance/life' : '/admin/insurance/health';

  console.log('📍 Base URL:', baseUrl);

  // Handle broker code type change
  console.log('🎧 Adding event listener to broker code select:', brokerCodeSelect.id);
  brokerCodeSelect.addEventListener('change', function() {
    const brokerType = this.value;
    console.log('🔄 Broker code type changed to:', brokerType);
    console.log('🔄 Event fired! Broker type:', brokerType);

    // Clear dependent dropdowns
    clearDropdown(agencyCodeSelect, 'Select Agency Code...');
    clearDropdown(insuranceCompanySelect, 'Select Insurance Company...');

    // Update labels based on broker type
    updateAgencyCodeLabel(agencyCodeLabel, brokerType);

    if (brokerType === 'direct') {
      // FLOW 1: Direct mode
      handleDirectMode(baseUrl, agencyCodeSelect, insuranceCompanySelect);
    } else if (brokerType === 'broking') {
      // FLOW 2: Broking mode
      handleBrokingMode(baseUrl, agencyCodeSelect, insuranceCompanySelect);
    }
  });

  // Handle agency code selection
  console.log('🎧 Adding event listener to agency code select:', agencyCodeSelect.id);
  agencyCodeSelect.addEventListener('change', function() {
    const brokerType = brokerCodeSelect.value;
    const selectedValue = this.value;
    console.log('🔄 Agency code changed! Broker type:', brokerType, 'Selected value:', selectedValue);

    if (selectedValue && (brokerType === 'direct' || brokerType === 'broking')) {
      // Load insurance companies based on the selected agency and broker type
      loadInsuranceCompaniesByAgency(baseUrl, brokerType, selectedValue, insuranceCompanySelect);
    } else {
      // Clear insurance company dropdown if no agency is selected
      clearDropdown(insuranceCompanySelect, 'Select Insurance Company...');
    }
  });

  console.log('✅ Event listeners attached successfully');

  // Mark as initialized
  window.dynamicDropdownsInitialized = true;

  // Check if broker code type is already selected and trigger appropriate loading
  setTimeout(() => {
    console.log('🔍 Checking initial broker code type selection...');
    const currentBrokerType = brokerCodeSelect.value;
    console.log('Current broker type on page load:', currentBrokerType);

    if (currentBrokerType === 'direct') {
      console.log('🎯 Triggering Direct mode on page load');
      handleDirectMode(baseUrl, agencyCodeSelect, insuranceCompanySelect);
    } else if (currentBrokerType === 'broking') {
      console.log('🏢 Triggering Broking mode on page load');
      handleBrokingMode(baseUrl, agencyCodeSelect, insuranceCompanySelect);
    }
  }, 200);
}

// FLOW 1: Handle Direct Mode
function handleDirectMode(baseUrl, agencyCodeSelect, insuranceCompanySelect) {
  console.log('📋 FLOW 1: Handling Direct Mode');

  // 1. Call API to fetch agents for health insurance
  showLoading(agencyCodeSelect);

  fetch(`${baseUrl}/agency_codes_for_broker_type?broker_type=direct`)
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('✅ Loaded agents:', data.data.length);

        // 2. Populate "Agency Code (All Agents)" dropdown with agents
        populateDropdown(agencyCodeSelect, data.data, 'Select Agent...');

        // Clear insurance company dropdown - will be auto-filled when agent is selected
        clearDropdown(insuranceCompanySelect, 'Select Agent First...');
      } else {
        showError('Failed to load agents: ' + data.message);
      }
    })
    .catch(error => {
      console.error('❌ Error loading agents:', error);
      showError('Error loading agents');
    })
    .finally(() => {
      hideLoading(agencyCodeSelect);
    });
}

// FLOW 2: Handle Broking Mode
function handleBrokingMode(baseUrl, agencyCodeSelect, insuranceCompanySelect) {
  console.log('🏢 FLOW 2: Handling Broking Mode');

  // 1. Call API to fetch all brokers for health insurance
  showLoading(agencyCodeSelect);

  fetch(`${baseUrl}/agency_codes_for_broker_type?broker_type=broking`)
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('✅ Loaded brokers:', data.data.length);

        // 3. Populate "Agency Code" dropdown with brokers
        populateDropdown(agencyCodeSelect, data.data, 'Select Broker...');
      } else {
        showError('Failed to load brokers: ' + data.message);
      }
    })
    .catch(error => {
      console.error('❌ Error loading brokers:', error);
      showError('Error loading brokers');
    })
    .finally(() => {
      hideLoading(agencyCodeSelect);
    });

  // 2. Call another API to fetch all health insurance companies
  // 3. Populate "Insurance Company Name" dropdown independently
  loadInsuranceCompaniesIndependent(baseUrl, insuranceCompanySelect);
}

// Load insurance companies independently (for Broking mode)
function loadInsuranceCompaniesIndependent(baseUrl, insuranceCompanySelect) {
  console.log('🏥 Loading insurance companies independently...');

  showLoading(insuranceCompanySelect);

  fetch(`${baseUrl}/insurance_companies_for_type`)
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('✅ Loaded companies:', data.data.length);
        populateDropdown(insuranceCompanySelect, data.data, 'Select Insurance Company...');
      } else {
        showError('Failed to load insurance companies: ' + data.message);
      }
    })
    .catch(error => {
      console.error('❌ Error loading insurance companies:', error);
      showError('Error loading insurance companies');
    })
    .finally(() => {
      hideLoading(insuranceCompanySelect);
    });
}

// Load insurance companies by agency (for both Direct and Broking modes)
function loadInsuranceCompaniesByAgency(baseUrl, brokerType, agencyCodeId, insuranceCompanySelect) {
  console.log('🏥 Loading insurance companies by agency - Broker Type:', brokerType, 'Agency ID:', agencyCodeId);

  showLoading(insuranceCompanySelect);

  // Prepare the request data
  const requestData = {
    broker_code: brokerType,
    agency_code_id: agencyCodeId
  };

  fetch(`${baseUrl}/insurance_companies_by_agency`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
    },
    body: JSON.stringify(requestData)
  })
    .then(response => response.json())
    .then(data => {
      if (data.success && data.data) {
        console.log('✅ Loaded insurance companies:', data.data.length);

        // Reset styling
        insuranceCompanySelect.style.backgroundColor = '';
        insuranceCompanySelect.style.cursor = '';

        // Populate dropdown with insurance companies
        const companies = data.data.map(company => ({
          id: company.name, // Use name as value for consistency
          text: company.name
        }));

        populateDropdown(insuranceCompanySelect, companies, 'Select Insurance Company...');
      } else {
        console.warn('⚠️ No insurance companies found or API error:', data.message);
        clearDropdown(insuranceCompanySelect, 'No companies available');
      }
    })
    .catch(error => {
      console.error('❌ Error loading insurance companies by agency:', error);
      showError('Error loading insurance companies');
      clearDropdown(insuranceCompanySelect, 'Error loading companies');
    })
    .finally(() => {
      hideLoading(insuranceCompanySelect);
    });
}

// FLOW 1: Auto-fill insurance company for selected agent (Direct mode only)
function autoFillInsuranceCompanyForAgent(baseUrl, agencyCodeId, insuranceCompanySelect) {
  console.log('🎯 FLOW 1: Auto-filling insurance company for agent ID:', agencyCodeId);

  showLoading(insuranceCompanySelect);

  fetch(`${baseUrl}/company_name_by_agent?agency_code_id=${agencyCodeId}`)
    .then(response => response.json())
    .then(data => {
      if (data.success && data.data.company_name) {
        const companyName = data.data.company_name;
        console.log('✅ Auto-filling company:', companyName);

        // Clear and set specific company
        clearDropdown(insuranceCompanySelect, 'Loading...');

        // 3. Auto-fill "Insurance Company Name" with that agent's company name
        // No separate API call needed for company name
        const option = document.createElement('option');
        option.value = companyName;
        option.textContent = companyName;
        option.selected = true;

        insuranceCompanySelect.appendChild(option);

        // Make it read-only style (user can see it but it's auto-selected)
        insuranceCompanySelect.style.backgroundColor = '#f8f9fa';
        insuranceCompanySelect.style.cursor = 'not-allowed';

        console.log('✅ Insurance company auto-filled and locked');
      } else {
        showError('Failed to get company for agent: ' + (data.message || 'Unknown error'));
      }
    })
    .catch(error => {
      console.error('❌ Error auto-filling company:', error);
      showError('Error auto-filling company');
    })
    .finally(() => {
      hideLoading(insuranceCompanySelect);
    });
}

// Utility functions
function clearDropdown(select, placeholder = 'Select...') {
  select.innerHTML = `<option value="">${placeholder}</option>`;

  // Reset styling
  select.style.backgroundColor = '';
  select.style.cursor = '';
}

function populateDropdown(select, data, placeholder = 'Select...') {
  select.innerHTML = `<option value="">${placeholder}</option>`;

  data.forEach(item => {
    const option = document.createElement('option');
    option.value = item.id;
    option.textContent = item.text;
    select.appendChild(option);
  });
}

function updateAgencyCodeLabel(labelElement, brokerType) {
  if (!labelElement) return;

  if (brokerType === 'direct') {
    labelElement.textContent = 'Agency Code (All Agents)*';
    console.log('📝 Updated label to: All Agents');
  } else if (brokerType === 'broking') {
    labelElement.textContent = 'Agency Code (All Brokers)*';
    console.log('📝 Updated label to: All Brokers');
  }
}

function showLoading(select) {
  select.disabled = true;
  select.style.opacity = '0.6';

  // Add loading option
  const loadingOption = document.createElement('option');
  loadingOption.value = '';
  loadingOption.textContent = 'Loading...';
  loadingOption.disabled = true;

  select.innerHTML = '';
  select.appendChild(loadingOption);
}

function hideLoading(select) {
  select.disabled = false;
  select.style.opacity = '1';
}

function showError(message) {
  console.error('🚨 Error:', message);
  // You can add toast notification here if available
}

// Export to global scope
console.log('📄 Dynamic insurance dropdowns script loaded');
window.initializeDynamicDropdowns = initializeDynamicDropdowns;
console.log('✅ initializeDynamicDropdowns function exported to window');

// Auto-initialize when DOM is ready, but only if not already initialized
document.addEventListener('DOMContentLoaded', function() {
  // Add a small delay to ensure other scripts load first
  setTimeout(() => {
    console.log('🚀 Auto-initializing dynamic dropdowns on DOMContentLoaded...');
    if (!window.dynamicDropdownsInitialized) {
      initializeDynamicDropdowns();
      window.dynamicDropdownsInitialized = true;
    }
  }, 100);
});

// Also initialize on Turbo navigation (for edit/show pages)
document.addEventListener('turbo:load', function() {
  setTimeout(() => {
    console.log('🚀 Auto-initializing dynamic dropdowns on turbo:load...');
    // Reset flag for Turbo navigation since elements might be new
    window.dynamicDropdownsInitialized = false;
    initializeDynamicDropdowns();
  }, 100);
});