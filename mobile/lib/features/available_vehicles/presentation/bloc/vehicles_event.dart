part of 'vehicles_bloc.dart';

abstract class VehiclesEvent extends Equatable {
  const VehiclesEvent();
  @override
  List<Object?> get props => [];
}

class LoadVehiclesEvent extends VehiclesEvent {
  final int page;
  final Map<String, dynamic>? filters;
  const LoadVehiclesEvent({this.page = 1, this.filters});
  @override
  List<Object?> get props => [page, filters];
}

class LoadMoreVehiclesEvent extends VehiclesEvent {}

class CreateVehicleEvent extends VehiclesEvent {
  final Map<String, dynamic> data;
  const CreateVehicleEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class DeleteVehicleEvent extends VehiclesEvent {
  final String id;
  const DeleteVehicleEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class FilterVehiclesEvent extends VehiclesEvent {
  final Map<String, dynamic> filters;
  const FilterVehiclesEvent(this.filters);
  @override
  List<Object?> get props => [filters];
}
