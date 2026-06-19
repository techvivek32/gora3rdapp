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

  HomeBloc(this.apiClient, this.sharedPreferences) : super(HomeInitial()) {
    on<LoadHomeDataEvent>(_onLoad);
    on<LoadSelectedCitiesEvent>(_onLoadSelectedCities);
    on<ToggleCityEvent>(_onToggleCity);
    on<SaveSelectedCitiesEvent>(_onSaveSelectedCities);
    on<LoadAvailableCitiesEvent>(_onLoadAvailableCities);
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
        await apiClient.put('/users/business-cities', data: {'cities': current.selectedCities});
        await sharedPreferences.setStringList(_selectedCitiesKey, current.selectedCities);
        emit(current.copyWith(selectedCities: current.selectedCities));
      } catch (e) {
        emit(HomeError(message: e.toString()));
      }
    }
  }

  Future<void> _onLoadAvailableCities(LoadAvailableCitiesEvent event, Emitter<HomeState> emit) async {
    if (state is! HomeLoaded) return;
    final current = state as HomeLoaded;
    if (current.availableCities.isNotEmpty) return;
    try {
      final res = await apiClient.get('/cities');
      final cities = (res.data['data'] as List<dynamic>? ?? [])
          .map((c) => (c as Map<String, dynamic>)['name'] as String)
          .toList();
      emit(current.copyWith(availableCities: cities));
    } catch (_) {}
  }
}
