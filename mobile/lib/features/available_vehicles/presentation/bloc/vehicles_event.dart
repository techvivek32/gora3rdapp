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

class LoadVehicleDetailEvent extends VehiclesEvent {
  final String id;
  const LoadVehicleDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class UpdateVehicleEvent extends VehiclesEvent {
  final String id;
  final Map<String, dynamic> data;
  const UpdateVehicleEvent({required this.id, required this.data});
  @override
  List<Object?> get props => [id, data];
}

class CancelVehicleEvent extends VehiclesEvent {
  final String id;
  final String reason;
  const CancelVehicleEvent({required this.id, required this.reason});
  @override
  List<Object?> get props => [id, reason];
}

class AcceptVehicleEvent extends VehiclesEvent {
  final String id;
  const AcceptVehicleEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class LoadMyVehiclesEvent extends VehiclesEvent {
  const LoadMyVehiclesEvent();
}

class SetVehicleStatusEvent extends VehiclesEvent {
  final String id;
  final String status;
  const SetVehicleStatusEvent({required this.id, required this.status});
  @override
  List<Object?> get props => [id, status];
}
