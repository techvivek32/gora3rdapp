import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_client.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ApiClient apiClient;

  HomeBloc(this.apiClient) : super(HomeInitial()) {
    on<LoadHomeDataEvent>(_onLoad);
  }

  Future<void> _onLoad(LoadHomeDataEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      final results = await Future.wait([
        apiClient.get('/banners'),
        apiClient.get('/requirements', params: {'limit': '5', 'page': '1'}),
      ]);
      emit(HomeLoaded(
        banners: List<Map<String, dynamic>>.from(results[0].data['data'] ?? []),
        recentRequirements: List<Map<String, dynamic>>.from(results[1].data['data'] ?? []),
      ));
    } catch (e) {
      emit(HomeError(message: e.toString()));
    }
  }
}
