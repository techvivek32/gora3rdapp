part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class LoadHomeDataEvent extends HomeEvent {
  const LoadHomeDataEvent();
}
class RefreshHomeEvent extends HomeEvent {
  const RefreshHomeEvent();
}
class LoadSelectedCitiesEvent extends HomeEvent {
  const LoadSelectedCitiesEvent();
}
class ToggleCityEvent extends HomeEvent {
  final String city;
  const ToggleCityEvent(this.city);
  @override
  List<Object?> get props => [city];
}
class SaveSelectedCitiesEvent extends HomeEvent {
  const SaveSelectedCitiesEvent();
}

