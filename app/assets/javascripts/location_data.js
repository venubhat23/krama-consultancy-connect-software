// Fallback location data for client-side use
window.LocationData = {
  // Helper method to get states in select format
  states_for_select: [
    ['Andhra Pradesh', 'andhra_pradesh'],
    ['Bihar', 'bihar'],
    ['Delhi', 'delhi'],
    ['Gujarat', 'gujarat'],
    ['Karnataka', 'karnataka'],
    ['Kerala', 'kerala'],
    ['Madhya Pradesh', 'madhya_pradesh'],
    ['Maharashtra', 'maharashtra'],
    ['Rajasthan', 'rajasthan'],
    ['Tamil Nadu', 'tamil_nadu'],
    ['Uttar Pradesh', 'uttar_pradesh'],
    ['West Bengal', 'west_bengal']
  ],

  states: {
    'andhra_pradesh': {
      name: 'Andhra Pradesh',
      cities: ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Rajahmundry', 'Tirupati', 'Kadapa', 'Kakinada', 'Anantapur']
    },
    'bihar': {
      name: 'Bihar',
      cities: ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga', 'Arrah', 'Begusarai', 'Katihar', 'Munger']
    },
    'delhi': {
      name: 'Delhi',
      cities: ['New Delhi', 'Central Delhi', 'North Delhi', 'South Delhi', 'East Delhi', 'West Delhi', 'Dwarka', 'Rohini', 'Janakpuri', 'Laxmi Nagar']
    },
    'gujarat': {
      name: 'Gujarat',
      cities: ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Junagadh', 'Gandhinagar', 'Anand', 'Navsari']
    },
    'karnataka': {
      name: 'Karnataka',
      cities: [
        // Belagavi Division (Northern Karnataka)
        'Belagavi', 'Bagalkote', 'Dharwad', 'Gadag', 'Haveri', 'Uttara Kannada', 'Vijayapura',

        // Bengaluru Division (Central Karnataka)
        'Bengaluru Urban', 'Bengaluru Rural', 'Chikkaballapura', 'Chitradurga', 'Davanagere', 'Kolar', 'Ramanagara', 'Shivamogga', 'Tumakuru',

        // Kalaburagi Division (North-East Karnataka)
        'Ballari', 'Bidar', 'Kalaburagi', 'Koppal', 'Raichur', 'Vijayanagara', 'Yadgir',

        // Mysuru Division (Southern Karnataka)
        'Chamarajanagar', 'Chikkamagaluru', 'Dakshina Kannada', 'Hassan', 'Kodagu', 'Mandya', 'Mysuru', 'Udupi',

        // Major Cities (Alternative/Popular Names)
        'Bangalore', 'Mysore', 'Mangaluru', 'Hubli-Dharwad', 'Belgaum', 'Gulbarga', 'Bellary', 'Bijapur', 'Shimoga', 'Tumkur', 'Hospet', 'Madikeri', 'Karwar', 'Chikmagalur', 'Chamrajnagar', 'Chikko'
      ]
    },
    'kerala': {
      name: 'Kerala',
      cities: ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Kollam', 'Thrissur', 'Alappuzha', 'Palakkad', 'Kannur', 'Kottayam', 'Malappuram']
    },
    'madhya_pradesh': {
      name: 'Madhya Pradesh',
      cities: ['Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Dewas', 'Satna', 'Ratlam', 'Rewa']
    },
    'maharashtra': {
      name: 'Maharashtra',
      cities: ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Nashik', 'Aurangabad', 'Solapur', 'Amravati', 'Kolhapur', 'Vasai-Virar', 'Kalyan-Dombivli', 'Sangli', 'Malegaon', 'Akola', 'Latur', 'Dhule', 'Ahmednagar', 'Chandrapur', 'Parbhani', 'Ichalkaranji']
    },
    'punjab': {
      name: 'Punjab',
      cities: ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali', 'Pathankot', 'Hoshiarpur', 'Batala', 'Moga']
    },
    'rajasthan': {
      name: 'Rajasthan',
      cities: ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer', 'Bikaner', 'Alwar', 'Bharatpur', 'Sikar', 'Pali']
    },
    'tamil_nadu': {
      name: 'Tamil Nadu',
      cities: ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli', 'Tiruppur', 'Vellore', 'Erode', 'Thoothukkudi']
    },
    'telangana': {
      name: 'Telangana',
      cities: ['Hyderabad', 'Warangal', 'Nizamabad', 'Khammam', 'Karimnagar', 'Ramagundam', 'Mahabubnagar', 'Nalgonda', 'Adilabad', 'Suryapet']
    },
    'uttar_pradesh': {
      name: 'Uttar Pradesh',
      cities: ['Lucknow', 'Kanpur', 'Ghaziabad', 'Agra', 'Varanasi', 'Meerut', 'Allahabad', 'Bareilly', 'Aligarh', 'Moradabad']
    },
    'west_bengal': {
      name: 'West Bengal',
      cities: ['Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri', 'Malda', 'Bardhaman', 'Barasat', 'Raiganj', 'Kharagpur']
    }
  },

  getCitiesForState: function(stateKey) {
    const state = this.states[stateKey];
    return state ? state.cities : [];
  },

  searchCitiesInState: function(stateKey, query) {
    const cities = this.getCitiesForState(stateKey);
    if (!query) return cities.slice(0, 10);

    const queryLower = query.toLowerCase();
    return cities.filter(city =>
      city.toLowerCase().includes(queryLower)
    ).slice(0, 20);
  }
};