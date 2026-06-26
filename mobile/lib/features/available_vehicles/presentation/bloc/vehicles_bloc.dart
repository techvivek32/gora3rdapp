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
    on<LoadVehicleDetailEvent>(_onLoadDetail);
    on<UpdateVehicleEvent>(_onUpdate);
    on<CancelVehicleEvent>(_onCancel);
    on<AcceptVehicleEvent>(_onAccept);
    on<LoadMyVehiclesEvent>(_onLoadMy);
    on<SetVehicleStatusEvent>(_onSetStatus);
  }

  Future<void> _onLoadMy(LoadMyVehiclesEvent event, Emitter<VehiclesState> emit) async {
    emit(VehiclesLoading());
    final result = await repository.getMyVehicles();
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (data) => emit(MyVehiclesLoaded(vehicles: List<Map<String, dynamic>>.from(data['data'] ?? []))),
    );
  }

  Future<void> _onSetStatus(SetVehicleStatusEvent event, Emitter<VehiclesState> emit) async {
    final result = await repository.setStatus(event.id, event.status);
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (_) => add(const LoadMyVehiclesEvent()),
    );
  }

  Future<void> _onLoad(LoadVehiclesEvent event, Emitter<VehiclesState> emit) async {
    emit(VehiclesLoading());
    final result = await repository.getVehicles(page: event.page, filters: event.filters);
    final myAcceptedResult = await repository.getAcceptedByMe();

    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (data) {
        final myAccepted = myAcceptedResult.fold(
          (_) => const <Map<String, dynamic>>[],
          (my) => List<Map<String, dynamic>>.from(my['data'] ?? []),
        );
        emit(VehiclesLoaded(
          vehicles: List<Map<String, dynamic>>.from(data['data'] ?? []),
          myAccepted: myAccepted,
        ));
      },
    );
  }

  Future<void> _onCreate(CreateVehicleEvent event, Emitter<VehiclesState> emit) async {
    final result = await repository.createVehicle(event.data);
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (data) { emit(VehicleCreated(vehicle: data)); add(const LoadVehiclesEvent()); },
    );
  }

  Future<void> _onDelete(DeleteVehicleEvent event, Emitter<VehiclesState> emit) async {
    final result = await repository.deleteVehicle(event.id);
    result.fold((f) => emit(VehiclesError(message: f.message)), (_) => add(LoadVehiclesEvent()));
  }

  Future<void> _onLoadDetail(LoadVehicleDetailEvent event, Emitter<VehiclesState> emit) async {
    emit(VehiclesLoading());
    final result = await repository.getVehicleById(event.id);
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (data) => emit(VehicleDetailLoaded(vehicle: data['data'] as Map<String, dynamic>? ?? data)),
    );
  }

  Future<void> _onUpdate(UpdateVehicleEvent event, Emitter<VehiclesState> emit) async {
    emit(VehiclesLoading());
    final result = await repository.updateVehicle(event.id, event.data);
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (data) => emit(VehicleUpdated(vehicle: data['data'] as Map<String, dynamic>? ?? data)),
    );
  }

  Future<void> _onCancel(CancelVehicleEvent event, Emitter<VehiclesState> emit) async {
    emit(VehiclesLoading());
    final result = await repository.cancelVehicle(event.id, event.reason);
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (_) => emit(VehicleCancelled()),
    );
  }

  Future<void> _onAccept(AcceptVehicleEvent event, Emitter<VehiclesState> emit) async {
    final result = await repository.acceptVehicle(event.id);
    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (_) {
        emit(VehicleAccepted());
        add(LoadVehicleDetailEvent(event.id));
      },
    );
  }
}
