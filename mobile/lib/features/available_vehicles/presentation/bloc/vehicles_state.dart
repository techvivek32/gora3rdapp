part of 'vehicles_bloc.dart';

abstract class VehiclesState extends Equatable {
  const VehiclesState();
  @override
  List<Object?> get props => [];
}

class VehiclesInitial extends VehiclesState {}
class VehiclesLoading extends VehiclesState {}

class VehiclesLoaded extends VehiclesState {
  final List<Map<String, dynamic>> vehicles;
  final bool hasMore;
  final int currentPage;
  const VehiclesLoaded({required this.vehicles, this.hasMore = false, this.currentPage = 1});
  @override
  List<Object?> get props => [vehicles, hasMore, currentPage];

  VehiclesLoaded copyWith({List<Map<String, dynamic>>? vehicles, bool? hasMore, int? currentPage}) {
    return VehiclesLoaded(
      vehicles: vehicles ?? this.vehicles,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class VehicleCreated extends VehiclesState {
  final Map<String, dynamic> vehicle;
  const VehicleCreated({required this.vehicle});
  @override
  List<Object?> get props => [vehicle];
}

class VehicleDetailLoaded extends VehiclesState {
  final Map<String, dynamic> vehicle;
  const VehicleDetailLoaded({required this.vehicle});
  @override
  List<Object?> get props => [vehicle];
}

class VehicleUpdated extends VehiclesState {
  final Map<String, dynamic> vehicle;
  const VehicleUpdated({required this.vehicle});
  @override
  List<Object?> get props => [vehicle];
}

class VehicleCancelled extends VehiclesState {}

class VehiclesError extends VehiclesState {
  final String message;
  const VehiclesError({required this.message});
  @override
  List<Object?> get props => [message];
}
