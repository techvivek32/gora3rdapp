part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}
class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> recentRequirements;
  const HomeLoaded({required this.banners, required this.recentRequirements});
  @override
  List<Object?> get props => [banners, recentRequirements];
}

class HomeError extends HomeState {
  final String message;
  const HomeError({required this.message});
  @override
  List<Object?> get props => [message];
}
