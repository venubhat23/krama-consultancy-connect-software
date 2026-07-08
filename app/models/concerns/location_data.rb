module LocationData
  STATES_AND_CITIES = {
    'andhra_pradesh' => {
      name: 'Andhra Pradesh',
      cities: [
        'Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Rajahmundry', 'Tirupati', 'Kadapa', 'Kakinada', 'Anantapur',
        'Eluru', 'Ongole', 'Nandyal', 'Machilipatnam', 'Adoni', 'Tenali', 'Chittoor', 'Hindupur', 'Proddatur', 'Bhimavaram',
        'Madanapalle', 'Guntakal', 'Dharmavaram', 'Gudivada', 'Narasaraopet', 'Tadipatri', 'Mangalagiri', 'Chilakaluripet'
      ]
    },
    'assam' => {
      name: 'Assam',
      cities: [
        'Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia', 'Tezpur', 'Bongaigaon', 'Karimganj', 'Dhubri',
        'North Lakhimpur', 'Goalpara', 'Sivasagar', 'Diphu', 'Mangaldoi', 'Haflong', 'Kokrajhar', 'Hailakandi', 'Morigaon', 'Nalbari'
      ]
    },
    'bihar' => {
      name: 'Bihar',
      cities: [
        'Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga', 'Arrah', 'Begusarai', 'Katihar', 'Munger',
        'Chapra', 'Danapur', 'Saharsa', 'Sasaram', 'Hajipur', 'Dehri', 'Siwan', 'Motihari', 'Nawada', 'Bagaha',
        'Buxar', 'Kishanganj', 'Sitamarhi', 'Jamalpur', 'Jehanabad', 'Aurangabad', 'Lakhisarai', 'Madhubani'
      ]
    },
    'chhattisgarh' => {
      name: 'Chhattisgarh',
      cities: [
        'Raipur', 'Bhilai', 'Korba', 'Bilaspur', 'Durg', 'Rajnandgaon', 'Jagdalpur', 'Raigarh', 'Ambikapur', 'Mahasamund',
        'Dhamtari', 'Chirmiri', 'Bhatapara', 'Dalli-Rajhara', 'Naila Janjgir', 'Tilda Newra', 'Mungeli', 'Pathalgaon'
      ]
    },
    'delhi' => {
      name: 'Delhi',
      cities: [
        'New Delhi', 'Central Delhi', 'North Delhi', 'South Delhi', 'East Delhi', 'West Delhi', 'North East Delhi', 'North West Delhi', 'South East Delhi', 'South West Delhi',
        'Shahdara', 'Dwarka', 'Rohini', 'Janakpuri', 'Laxmi Nagar', 'Karol Bagh', 'Connaught Place', 'Vasant Vihar', 'Greater Kailash', 'Saket'
      ]
    },
    'goa' => {
      name: 'Goa',
      cities: [
        'Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda', 'Bicholim', 'Curchorem', 'Sanquelim', 'Cuncolim', 'Quepem',
        'Canacona', 'Sanguem', 'Pernem', 'Sattari', 'Aldona', 'Arambol', 'Benaulim', 'Calangute', 'Candolim', 'Colva'
      ]
    },
    'gujarat' => {
      name: 'Gujarat',
      cities: [
        'Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Junagadh', 'Gandhinagar', 'Anand', 'Navsari',
        'Bharuch', 'Mehsana', 'Morbi', 'Nadiad', 'Surendranagar', 'Gandhidham', 'Veraval', 'Palanpur', 'Vapi', 'Godhra',
        'Patan', 'Kalol', 'Dahod', 'Botad', 'Amreli', 'Deesa', 'Jetpur', 'Porbandar', 'Himatnagar', 'Bhuj'
      ]
    },
    'haryana' => {
      name: 'Haryana',
      cities: [
        'Faridabad', 'Gurgaon', 'Panipat', 'Ambala', 'Yamunanagar', 'Rohtak', 'Hisar', 'Karnal', 'Sonipat', 'Panchkula',
        'Bhiwani', 'Sirsa', 'Bahadurgarh', 'Jind', 'Thanesar', 'Kaithal', 'Palwal', 'Rewari', 'Hansi', 'Narnaul',
        'Fatehabad', 'Gohana', 'Tohana', 'Narwana', 'Mandi Dabwali', 'Charkhi Dadri', 'Shahabad', 'Pehowa'
      ]
    },
    'himachal_pradesh' => {
      name: 'Himachal Pradesh',
      cities: [
        'Shimla', 'Dharamshala', 'Solan', 'Mandi', 'Palampur', 'Baddi', 'Nahan', 'Paonta Sahib', 'Sundernagar', 'Chamba',
        'Una', 'Kullu', 'Hamirpur', 'Bilaspur', 'Yol', 'Jubbal', 'Chail', 'Gagret', 'Kangra', 'Nalagarh',
        'Nurpur', 'Manali', 'Kasauli', 'Dalhousie', 'Mcleodganj', 'Kinnaur', 'Lahaul', 'Spiti'
      ]
    },
    'jharkhand' => {
      name: 'Jharkhand',
      cities: [
        'Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar', 'Phusro', 'Hazaribagh', 'Giridih', 'Ramgarh', 'Medininagar',
        'Chirkunda', 'Chaibasa', 'Gumla', 'Dumka', 'Madhupur', 'Sahibganj', 'Jhumri Telaiya', 'Mihijam', 'Pakaur', 'Lohardaga',
        'Tenughat', 'Koderma', 'Godda', 'Jamtara', 'Khunti', 'Garhwa', 'Simdega', 'Seraikela'
      ]
    },
    'karnataka' => {
      name: 'Karnataka',
      cities: [
        # Belagavi Division (Northern Karnataka)
        'Belagavi', 'Bagalkote', 'Dharwad', 'Gadag', 'Haveri', 'Uttara Kannada', 'Vijayapura',

        # Bengaluru Division (Central Karnataka)
        'Bengaluru Urban', 'Bengaluru Rural', 'Chikkaballapura', 'Chitradurga', 'Davanagere', 'Kolar', 'Ramanagara', 'Shivamogga', 'Tumakuru',

        # Kalaburagi Division (North-East Karnataka)
        'Ballari', 'Bidar', 'Kalaburagi', 'Koppal', 'Raichur', 'Vijayanagara', 'Yadgir',

        # Mysuru Division (Southern Karnataka)
        'Chamarajanagar', 'Chikkamagaluru', 'Dakshina Kannada', 'Hassan', 'Kodagu', 'Mandya', 'Mysuru', 'Udupi',

        # Major Cities/Towns (Alternative/Popular Names)
        'Bangalore', 'Mysore', 'Mangaluru', 'Hubli-Dharwad', 'Belgaum', 'Gulbarga', 'Bellary', 'Bijapur', 'Shimoga', 'Tumkur', 'Hospet', 'Madikeri', 'Karwar', 'Chikmagalur', 'Chamrajnagar',

        # Additional Cities
        'Gadag-Betigeri', 'Bhadravati', 'Gangavati', 'Ranebennuru', 'Robertsonpet', 'Nanjangud', 'Tiptur', 'Sirsi', 'Puttur', 'Bhatkal', 'Gokak', 'Madhugiri', 'Kundapura', 'Sandur', 'Arsikere', 'Chikko'
      ]
    },
    'kerala' => {
      name: 'Kerala',
      cities: [
        'Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Kollam', 'Thrissur', 'Alappuzha', 'Palakkad', 'Kannur', 'Kottayam', 'Malappuram',
        'Thalassery', 'Ponnani', 'Vatakara', 'Kanhangad', 'Payyanur', 'Koyilandy', 'Parappanangadi', 'Kalamassery', 'Neyyattinkara', 'Kayamkulam',
        'Nedumangad', 'Kattappana', 'Muvattuupuzha', 'Nilambur', 'Cherthala', 'Sultan Bathery', 'Maradu', 'Kalpetta', 'Perinthalmanna', 'Mattannur'
      ]
    },
    'madhya_pradesh' => {
      name: 'Madhya Pradesh',
      cities: [
        'Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Dewas', 'Satna', 'Ratlam', 'Rewa',
        'Murwara', 'Singrauli', 'Burhanpur', 'Khandwa', 'Bhind', 'Chhindwara', 'Guna', 'Shivpuri', 'Vidisha', 'Chhatarpur',
        'Damoh', 'Mandsaur', 'Khargone', 'Neemuch', 'Pithampur', 'Narmadapuram', 'Itarsi', 'Sehore', 'Betul', 'Seoni'
      ]
    },
    'maharashtra' => {
      name: 'Maharashtra',
      cities: [
        'Mumbai', 'Pune', 'Nagpur', 'Thane', 'Nashik', 'Aurangabad', 'Solapur', 'Amravati', 'Kolhapur', 'Vasai-Virar',
        'Kalyan-Dombivli', 'Sangli', 'Malegaon', 'Akola', 'Latur', 'Dhule', 'Ahmednagar', 'Chandrapur', 'Parbhani', 'Ichalkaranji',
        'Jalgaon', 'Bhusawal', 'Panvel', 'Ambarnath', 'Satara', 'Beed', 'Yavatmal', 'Kamptee', 'Gondiya', 'Barshi',
        'Achalpur', 'Osmanabad', 'Nanded', 'Wardha', 'Udgir', 'Hinganghat', 'Washim', 'Gadchiroli', 'Sindhudurg', 'Ratnagiri'
      ]
    },
    'manipur' => {
      name: 'Manipur',
      cities: [
        'Imphal', 'Thoubal', 'Lilong', 'Mayang Imphal', 'Kakching', 'Nambol', 'Moirang', 'Lamding', 'Ukhrul', 'Senapati',
        'Tamenglong', 'Churachandpur', 'Bishnupur', 'Jiribam', 'Chandel', 'Noney', 'Kangpokpi', 'Tengnoupal', 'Kamjong', 'Pherzawl'
      ]
    },
    'meghalaya' => {
      name: 'Meghalaya',
      cities: [
        'Shillong', 'Tura', 'Nongstoin', 'Jowai', 'Baghmara', 'Williamnagar', 'Nongpoh', 'Mairang', 'Resubelpara', 'Ampati',
        'Mawkyrwat', 'Cherrapunji', 'Mawsynram', 'Dawki', 'Bholaganj', 'Khliehriat', 'Amlarem', 'Ranikor', 'Mawshynrut', 'Tikrikilla'
      ]
    },
    'mizoram' => {
      name: 'Mizoram',
      cities: [
        'Aizawl', 'Lunglei', 'Champhai', 'Serchhip', 'Kolasib', 'Lawngtlai', 'Saitual', 'Mamit', 'Hnahthial', 'Khawzawl',
        'Zawlnuam', 'Saiha', 'Tlabung', 'Biate', 'Reiek', 'Thenzawl', 'Chawngte', 'Vairengte', 'North Vanlaiphai', 'Tuipang'
      ]
    },
    'nagaland' => {
      name: 'Nagaland',
      cities: [
        'Kohima', 'Dimapur', 'Wokha', 'Mokokchung', 'Tuensang', 'Mon', 'Phek', 'Kiphire', 'Longleng', 'Peren',
        'Zunheboto', 'Noklak', 'Chumoukedima', 'Tseminyu', 'Jalukie', 'Tizit', 'Shamator', 'Angetyongpang', 'Changtongya', 'Longding'
      ]
    },
    'odisha' => {
      name: 'Odisha',
      cities: [
        'Bhubaneswar', 'Cuttack', 'Rourkela', 'Brahmapur', 'Sambalpur', 'Puri', 'Balasore', 'Bhadrak', 'Baripada', 'Jharsuguda',
        'Jeypore', 'Barbil', 'Khordha', 'Bolangir', 'Sundargarh', 'Rayagada', 'Kendrapara', 'Koraput', 'Paradip', 'Dhenkanal',
        'Angul', 'Nabarangpur', 'Jajpur', 'Kendujhar', 'Kalahandi', 'Mayurbhanj', 'Nayagarh', 'Nuapada', 'Sonepur', 'Malkangiri'
      ]
    },
    'punjab' => {
      name: 'Punjab',
      cities: [
        'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali', 'Pathankot', 'Hoshiarpur', 'Batala', 'Moga',
        'Abohar', 'Malerkotla', 'Khanna', 'Phagwara', 'Muktsar', 'Barnala', 'Rajpura', 'Firozpur', 'Kapurthala', 'Zirakpur',
        'Kot Kapura', 'Faridkot', 'Sunam', 'Jagraon', 'Dhuri', 'Nabha', 'Mansa', 'Gurdaspur', 'Kharar', 'Gobindgarh'
      ]
    },
    'rajasthan' => {
      name: 'Rajasthan',
      cities: [
        'Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer', 'Bikaner', 'Alwar', 'Bharatpur', 'Sikar', 'Pali',
        'Sri Ganganagar', 'Kishangarh', 'Beawar', 'Dhaulpur', 'Tonk', 'Bhilwara', 'Hanumangarh', 'Sawai Madhopur', 'Jhunjhunu', 'Barmer',
        'Churu', 'Nagaur', 'Jaisalmer', 'Banswara', 'Bundi', 'Dausa', 'Mount Abu', 'Makrana', 'Sujangarh', 'Lachhmangarh'
      ]
    },
    'sikkim' => {
      name: 'Sikkim',
      cities: [
        'Gangtok', 'Namchi', 'Gyalshing', 'Mangan', 'Singtam', 'Jorethang', 'Nayabazar', 'Rangpo', 'Ravangla', 'Yuksom',
        'Pelling', 'Rongli', 'Rhenock', 'Lachung', 'Lachen', 'Tsomgo', 'Nathu La', 'Gurudongmar', 'Khecheopalri', 'Tashiding'
      ]
    },
    'tamil_nadu' => {
      name: 'Tamil Nadu',
      cities: [
        'Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli', 'Tiruppur', 'Vellore', 'Erode', 'Thoothukkudi',
        'Dindigul', 'Thanjavur', 'Ranipet', 'Sivakasi', 'Karur', 'Udhagamandalam', 'Hosur', 'Nagercoil', 'Kanchipuram', 'Kumarakonam',
        'Pudukkottai', 'Ambur', 'Rajapalayam', 'Pollachi', 'Virudhunagar', 'Neyveli', 'Nagapattinam', 'Viluppuram', 'Tiruvallur', 'Vaniyambadi',
        'Mettupalayam', 'Ariyalur', 'Chidambaram', 'Cuddalore', 'Dharmapuri', 'Krishnagiri', 'Mayiladuthurai', 'Namakkal', 'Perambalur', 'Tenkasi'
      ]
    },
    'telangana' => {
      name: 'Telangana',
      cities: [
        'Hyderabad', 'Warangal', 'Nizamabad', 'Khammam', 'Karimnagar', 'Ramagundam', 'Mahabubnagar', 'Nalgonda', 'Adilabad', 'Suryapet',
        'Miryalaguda', 'Jagtial', 'Mancherial', 'Nirmal', 'Kothagudem', 'Bodhan', 'Sangareddy', 'Metpally', 'Zaheerabad', 'Kamareddy',
        'Wanaparthy', 'Gadwal', 'Vikarabad', 'Jangaon', 'Medak', 'Siddipet', 'Korutla', 'Nagarkurnool', 'Bhongir', 'Narayanpet'
      ]
    },
    'tripura' => {
      name: 'Tripura',
      cities: [
        'Agartala', 'Dharmanagar', 'Udaipur', 'Kailasahar', 'Bishalgarh', 'Teliamura', 'Khowai', 'Belonia', 'Melaghar', 'Mohanpur',
        'Ambassa', 'Ranirbazar', 'Sonamura', 'Kumarghat', 'Santirbazar', 'Longtharai Valley', 'Gandacherra', 'Kamalpur', 'Sabroom', 'Manu'
      ]
    },
    'uttar_pradesh' => {
      name: 'Uttar Pradesh',
      cities: [
        'Lucknow', 'Kanpur', 'Ghaziabad', 'Agra', 'Varanasi', 'Meerut', 'Allahabad', 'Bareilly', 'Aligarh', 'Moradabad',
        'Saharanpur', 'Gorakhpur', 'Firozabad', 'Jhansi', 'Muzaffarnagar', 'Mathura', 'Rampur', 'Shahjahanpur', 'Farrukhabad', 'Mau',
        'Hapur', 'Etawah', 'Mirzapur', 'Bulandshahr', 'Sambhal', 'Amroha', 'Hardoi', 'Fatehpur', 'Raebareli', 'Orai',
        'Sitapur', 'Bahraich', 'Modinagar', 'Unnao', 'Jaunpur', 'Lakhimpur', 'Hathras', 'Banda', 'Pilibhit', 'Barabanki'
      ]
    },
    'uttarakhand' => {
      name: 'Uttarakhand',
      cities: [
        'Dehradun', 'Haridwar', 'Roorkee', 'Haldwani-cum-Kathgodam', 'Rudrapur', 'Kashipur', 'Rishikesh', 'Pithoragarh', 'Ramnagar', 'Rudraprayag',
        'Kotdwar', 'Mussoorie', 'Bageshwar', 'Champawat', 'Gopeshwar', 'Nainital', 'Almora', 'Tehri', 'Pauri', 'Srinagar',
        'Lansdowne', 'Chamba', 'Chakrata', 'Kichha', 'Jaspur', 'Sitarganj', 'Tanakpur', 'Vikasnagar', 'Joshimath', 'Kedarnath'
      ]
    },
    'west_bengal' => {
      name: 'West Bengal',
      cities: [
        'Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri', 'Malda', 'Bardhaman', 'Barasat', 'Raiganj', 'Kharagpur',
        'Haldia', 'Krishnanagar', 'Nabadwip', 'Medinipur', 'Jalpaiguri', 'Balurghat', 'Basirhat', 'Bankura', 'Chakdaha', 'Darjeeling',
        'Alipurduar', 'Purulia', 'Jangipur', 'Bangaon', 'Cooch Behar', 'Bolpur', 'Ranaghat', 'Midnapore', 'Tamluk', 'Kurseong',
        'Mayurbhanj', 'Raghunathpur', 'Egra', 'Bidhannagar', 'Barrackpore', 'Serampore', 'Chinsurah', 'Dum Dum', 'English Bazar', 'Gangarampur'
      ]
    }
  }.freeze

  def self.states_for_select
    STATES_AND_CITIES.map { |key, value| [value[:name], key] }.sort
  end

  def self.cities_for_state(state_key)
    return [] unless STATES_AND_CITIES[state_key]
    STATES_AND_CITIES[state_key][:cities].sort
  end

  def self.top_cities_for_state(state_key, limit = 10)
    cities_for_state(state_key).first(limit)
  end

  def self.search_cities_in_state(state_key, query, limit = 20)
    return [] unless STATES_AND_CITIES[state_key]
    cities = STATES_AND_CITIES[state_key][:cities]
    filtered = cities.select { |city| city.downcase.include?(query.downcase) }
    filtered.sort.first(limit)
  end
end