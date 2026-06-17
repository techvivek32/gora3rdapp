import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  final String _selectedCitiesKey = 'selected_cities';

  static const List<String> availableCities = [
    'Mumbai',
    'Delhi',
    'Bangalore',
    'Hyderabad',
    'Chennai',
    'Kolkata',
    'Ahmedabad',
    'Pune',
    'Surat',
    'Jaipur',
    'Lucknow',
    'Kanpur',
    'Nagpur',
    'Indore',
    'Thane',
    'Bhopal',
    'Visakhapatnam',
    'Pimpri-Chinchwad',
    'Patna',
    'Vadodara',
    'Ghaziabad',
    'Ludhiana',
    'Agra',
    'Nashik',
    'Faridabad',
    'Meerut',
    'Rajkot',
    'Kalyan-Dombivli',
    'Vasai-Virar',
    'Varanasi',
    'Srinagar',
    'Aurangabad',
    'Dhanbad',
    'Amritsar',
    'Navi Mumbai',
    'Allahabad',
    'Ranchi',
    'Howrah',
    'Coimbatore',
    'Jabalpur',
    'Gwalior',
    'Vijayawada',
    'Jodhpur',
    'Madurai',
    'Raipur',
    'Kota',
    'Guwahati',
    'Chandigarh',
    'Solapur',
    'Hubli-Dharwad',
    'Tiruchirappalli',
    'Mysore',
    'Tiruppur',
    'Bareilly',
    'Aligarh',
    'Moradabad',
    'Gurugram',
    'Jalandhar',
    'Bhubaneswar',
    'Salem',
    'Mira-Bhayandar',
    'Warangal',
    'Guntur',
    'Bhiwandi',
    'Saharanpur',
    'Gorakhpur',
    'Bikaner',
    'Amravati',
    'Noida',
    'Jamshedpur',
    'Bhilai',
    'Cuttack',
    'Firozabad',
    'Kochi',
    'Nellore',
    'Bhavnagar',
    'Dehradun',
    'Durgapur',
    'Asansol',
    'Nanded',
    'Kolhapur',
    'Ajmer',
    'Akola',
    'Gulbarga',
    'Jamnagar',
    'Ujjain',
    'Loni',
    'Siliguri',
    'Jhansi',
    'Ulhasnagar',
    'Jammu',
    'Sangli-Miraj & Kupwad',
    'Mangalore',
    'Erode',
    'Belgaum',
    'Ambattur',
    'Tirunelveli',
    'Malegaon',
    'Gaya',
    'Kakinada',
    'Thiruvananthapuram',
    'Davanagere',
    'Kozhikode',
    'Kurnool',
    'Rajahmundry',
    'Bokaro',
    'South Dumdum',
    'Bellary',
    'Patiala',
    'Gopalpur',
    'Agartala',
    'Bhagalpur',
    'Muzaffarnagar',
    'Bhatpara',
    'Panihati',
    'Latur',
    'Dhule',
    'Rohtak',
    'Sagar',
    'Ratlam',
    'Durg',
    'Bhilwara',
    'Berhampur',
    'Muzaffarpur',
    'Ahmednagar',
    'Kollam',
    'Rourkela',
    'Kottayam',
    'Ichalkaranji',
    'Tirupati',
    'Khandwa',
    'Fatehpur Sikri',
    'Dibrugarh',
    'Saharanpur',
    'Srikakulam',
    'Karimnagar',
    'Vellore',
    'Hapur',
    'Hindupur',
    'Burdwan',
    'Nellore',
    'Shahdara',
    'Vijayapura',
    'Aurangabad',
    'Nagercoil',
    'Parbhani',
    'Sangli',
    'Sikar',
    'Tumkur',
    'Mathura',
    'Rajkot',
  ];

  HomeBloc(this.apiClient, this.sharedPreferences) : super(HomeInitial()) {
    on<LoadHomeDataEvent>(_onLoad);
    on<LoadSelectedCitiesEvent>(_onLoadSelectedCities);
    on<ToggleCityEvent>(_onToggleCity);
    on<SaveSelectedCitiesEvent>(_onSaveSelectedCities);
  }

  Future<void> _onLoad(LoadHomeDataEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      final results = await Future.wait([
        apiClient.get('/banners'),
        apiClient.get('/requirements', params: {'limit': '5', 'page': '1'}),
        apiClient.get('/users/profile'),
      ]);
      final userProfile = results[2].data['data'] as Map<String, dynamic>;
      final selectedCities = List<String>.from(userProfile['businessCities'] ?? []);
      // Also save to local storage for offline
      await sharedPreferences.setStringList(_selectedCitiesKey, selectedCities);
      emit(HomeLoaded(
        banners: List<Map<String, dynamic>>.from(results[0].data['data'] ?? []),
        recentRequirements: List<Map<String, dynamic>>.from(results[1].data['data'] ?? []),
        selectedCities: selectedCities,
      ));
    } catch (e) {
      emit(HomeError(message: e.toString()));
    }
  }

  Future<void> _onLoadSelectedCities(LoadSelectedCitiesEvent event, Emitter<HomeState> emit) async {
    if (state is HomeLoaded) {
      final selectedCities = sharedPreferences.getStringList(_selectedCitiesKey) ?? [];
      emit((state as HomeLoaded).copyWith(selectedCities: selectedCities));
    }
  }

  Future<void> _onToggleCity(ToggleCityEvent event, Emitter<HomeState> emit) async {
    if (state is HomeLoaded) {
      final current = state as HomeLoaded;
      final updated = List<String>.from(current.selectedCities);
      if (updated.contains(event.city)) {
        updated.remove(event.city);
      } else {
        updated.add(event.city);
      }
      await sharedPreferences.setStringList(_selectedCitiesKey, updated);
      emit(current.copyWith(selectedCities: updated));
    }
  }

  Future<void> _onSaveSelectedCities(SaveSelectedCitiesEvent event, Emitter<HomeState> emit) async {
    if (state is HomeLoaded) {
      final current = state as HomeLoaded;
      try {
        emit(HomeSavingCities());
        // Save to backend
        await apiClient.put('/users/business-cities', data: {'cities': current.selectedCities});
        // Save to local storage
        await sharedPreferences.setStringList(_selectedCitiesKey, current.selectedCities);
        emit(HomeLoaded(
          banners: current.banners,
          recentRequirements: current.recentRequirements,
          selectedCities: current.selectedCities,
        ));
      } catch (e) {
        emit(HomeError(message: e.toString()));
      }
    }
  }
}
