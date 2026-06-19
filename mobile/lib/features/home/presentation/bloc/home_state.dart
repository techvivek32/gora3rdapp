part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}
class HomeLoading extends HomeState {}
class HomeSavingCities extends HomeState {}

class HomeLoaded extends HomeState {
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> recentRequirements;
  final List<String> selectedCities;
  final List<String> availableCities;
  const HomeLoaded({
    required this.banners,
    required this.recentRequirements,
    this.selectedCities = const [],
    this.availableCities = const [],
  });
  @override
  List<Object?> get props => [banners, recentRequirements, selectedCities, availableCities];

  HomeLoaded copyWith({
    List<Map<String, dynamic>>? banners,
    List<Map<String, dynamic>>? recentRequirements,
    List<String>? selectedCities,
    List<String>? availableCities,
  }) {
    return HomeLoaded(
      banners: banners ?? this.banners,
      recentRequirements: recentRequirements ?? this.recentRequirements,
      selectedCities: selectedCities ?? this.selectedCities,
      availableCities: availableCities ?? this.availableCities,
    );
  }
}

class HomeError extends HomeState {
  final String message;
  const HomeError({required this.message});
  @override
  List<Object?> get props => [message];
}
