import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/vehicles_repository.dart';

part 'vehicles_event.dart';
part 'vehicles_state.dart';

class VehiclesBloc extends Bloc<VehiclesEvent, VehiclesState> {
  final VehiclesRepository repository;

  VehiclesBloc(this.repository) : super(VehiclesInitial()) {
    on<LoadVehiclesEvent>(_onLoad);
    on<CreateVehicleEvent>(_onCreate);
    on<DeleteVehicleEvent>(_onDelete);
  }

  Future<void> _onLoad(LoadVehiclesEvent event, Emitter<VehiclesState> emit) async {
    emit(VehiclesLoading());
    final result = await repository.getVehicles(page: event.page, filters: event.filters);
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (data) => emit(VehiclesLoaded(vehicles: List<Map<String, dynamic>>.from(data['data'] ?? []))),
    );
  }

  Future<void> _onCreate(CreateVehicleEvent event, Emitter<VehiclesState> emit) async {
    final result = await repository.createVehicle(event.data);
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (data) { emit(VehicleCreated(vehicle: data)); add(LoadVehiclesEvent()); },
    );
  }

  Future<void> _onDelete(DeleteVehicleEvent event, Emitter<VehiclesState> emit) async {
    final result = await repository.deleteVehicle(event.id);
    result.fold((f) => emit(VehiclesError(message: f.message)), (_) => add(LoadVehiclesEvent()));
  }
}
