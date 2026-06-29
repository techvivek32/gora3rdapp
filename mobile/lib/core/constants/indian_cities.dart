/// A broad list of Indian cities used for city selection so users aren't limited
/// to the admin-curated list. Merged with admin cities at runtime.
const List<String> kIndianCities = [
  // Andhra Pradesh
  'Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Rajahmundry',
  'Kakinada', 'Tirupati', 'Anantapur', 'Kadapa', 'Eluru', 'Ongole', 'Chittoor',
  // Arunachal Pradesh
  'Itanagar', 'Naharlagun',
  // Assam
  'Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia', 'Tezpur',
  // Bihar
  'Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Darbhanga', 'Purnia', 'Arrah',
  'Begusarai', 'Katihar', 'Chapra', 'Bihar Sharif',
  // Chhattisgarh
  'Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Durg', 'Rajnandgaon', 'Jagdalpur',
  // Goa
  'Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda',
  // Gujarat
  'Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Junagadh',
  'Gandhinagar', 'Anand', 'Nadiad', 'Morbi', 'Mehsana', 'Bharuch', 'Navsari',
  'Vapi', 'Veraval', 'Porbandar', 'Gandhidham', 'Surendranagar', 'Palanpur',
  // Haryana
  'Faridabad', 'Gurugram', 'Panipat', 'Ambala', 'Yamunanagar', 'Rohtak', 'Hisar',
  'Karnal', 'Sonipat', 'Panchkula', 'Bhiwani', 'Sirsa', 'Bahadurgarh',
  // Himachal Pradesh
  'Shimla', 'Solan', 'Dharamshala', 'Mandi', 'Kullu', 'Manali', 'Baddi',
  // Jharkhand
  'Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar', 'Hazaribagh', 'Giridih',
  // Karnataka
  'Bangalore', 'Mysore', 'Hubli', 'Mangalore', 'Belgaum', 'Gulbarga', 'Davanagere',
  'Bellary', 'Bijapur', 'Shimoga', 'Tumkur', 'Raichur', 'Bidar', 'Hospet', 'Udupi',
  // Kerala
  'Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kollam', 'Kannur',
  'Alappuzha', 'Palakkad', 'Kottayam', 'Malappuram', 'Manjeri',
  // Madhya Pradesh
  'Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Dewas', 'Satna',
  'Ratlam', 'Rewa', 'Katni', 'Singrauli', 'Burhanpur', 'Khandwa', 'Chhindwara',
  // Maharashtra
  'Mumbai', 'Pune', 'Nagpur', 'Thane', 'Nashik', 'Aurangabad', 'Solapur',
  'Kalyan', 'Vasai-Virar', 'Navi Mumbai', 'Kolhapur', 'Amravati', 'Nanded',
  'Sangli', 'Jalgaon', 'Akola', 'Latur', 'Dhule', 'Ahmednagar', 'Chandrapur',
  'Parbhani', 'Ichalkaranji', 'Satara', 'Ratnagiri',
  // Manipur, Meghalaya, Mizoram, Nagaland
  'Imphal', 'Shillong', 'Aizawl', 'Kohima', 'Dimapur',
  // Odisha
  'Bhubaneswar', 'Cuttack', 'Rourkela', 'Berhampur', 'Sambalpur', 'Puri',
  'Balasore', 'Baripada',
  // Punjab
  'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali',
  'Hoshiarpur', 'Moga', 'Pathankot', 'Firozpur',
  // Rajasthan
  'Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Bikaner', 'Ajmer', 'Bhilwara',
  'Alwar', 'Sikar', 'Pali', 'Sri Ganganagar', 'Bharatpur', 'Chittorgarh',
  'Tonk', 'Kishangarh', 'Beawar', 'Hanumangarh',
  // Tamil Nadu
  'Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli',
  'Tiruppur', 'Vellore', 'Erode', 'Thoothukudi', 'Dindigul', 'Thanjavur',
  'Nagercoil', 'Karur', 'Hosur', 'Cuddalore', 'Kanchipuram',
  // Telangana
  'Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar', 'Khammam', 'Ramagundam',
  'Mahbubnagar', 'Nalgonda', 'Adilabad', 'Secunderabad',
  // Tripura
  'Agartala',
  // Uttar Pradesh
  'Lucknow', 'Kanpur', 'Ghaziabad', 'Agra', 'Varanasi', 'Meerut', 'Prayagraj',
  'Allahabad', 'Bareilly', 'Aligarh', 'Moradabad', 'Saharanpur', 'Gorakhpur',
  'Noida', 'Firozabad', 'Jhansi', 'Muzaffarnagar', 'Mathura', 'Ayodhya',
  'Rampur', 'Shahjahanpur', 'Etawah', 'Mirzapur', 'Bulandshahr', 'Hapur',
  // Uttarakhand
  'Dehradun', 'Haridwar', 'Roorkee', 'Haldwani', 'Rudrapur', 'Kashipur', 'Rishikesh',
  // West Bengal
  'Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri', 'Bardhaman',
  'Malda', 'Kharagpur', 'Haldia', 'Darjeeling',
  // Union Territories
  'Delhi', 'New Delhi', 'Chandigarh', 'Puducherry', 'Port Blair', 'Jammu',
  'Srinagar', 'Leh', 'Silvassa', 'Daman', 'Kavaratti',
];
