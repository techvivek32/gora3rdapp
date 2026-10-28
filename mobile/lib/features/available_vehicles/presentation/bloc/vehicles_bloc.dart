import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/vehicles_repository.dart';

part 'vehicles_event.dart';
part 'vehicles_state.dart';

class VehiclesBloc extends Bloc<VehiclesEvent, VehiclesState> {
  final VehiclesRepository repository;

  // Where the feed is up to. The page dispatches LoadMoreVehiclesEvent as you
  // near the bottom, exactly like the booking feed does.
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  Map<String, dynamic>? _filters;

  VehiclesBloc(this.repository) : super(VehiclesInitial()) {
    on<LoadVehiclesEvent>(_onLoad);
    on<LoadMoreVehiclesEvent>(_onLoadMore);
    on<RefreshVehiclesEvent>(_onRefresh);
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
    _page = event.page;
    _hasMore = false;
    _loadingMore = false;
    _filters = event.filters;

    final result = await repository.getVehicles(page: event.page, filters: event.filters);
    final myAcceptedResult = await repository.getAcceptedByMe();

    result.fold(
      (f) => emit(VehiclesError(message: f.message)),
      (data) {
        // The server says whether another page exists; without reading it the
        // feed stopped at the first page and the scroll never loaded anything.
        _hasMore = data['meta']?['hasNextPage'] ?? false;
        final myAccepted = myAcceptedResult.fold(
          (_) => const <Map<String, dynamic>>[],
          (my) => List<Map<String, dynamic>>.from(my['data'] ?? []),
        );
        emit(VehiclesLoaded(
          vehicles: List<Map<String, dynamic>>.from(data['data'] ?? []),
          myAccepted: myAccepted,
          hasMore: _hasMore,
          currentPage: _page,
        ));
      },
    );
  }

  /// Append the next page. Guarded here rather than at the call site, because
  /// the scroll listener fires on every frame near the bottom.
  Future<void> _onLoadMore(LoadMoreVehiclesEvent event, Emitter<VehiclesState> emit) async {
    final current = state;
    if (current is! VehiclesLoaded || !current.hasMore || _loadingMore) return;

    _loadingMore = true;
    final result = await repository.getVehicles(page: _page + 1, filters: _filters);
    result.fold(
      (_) => _loadingMore = false,
      (data) {
        final fetched = List<Map<String, dynamic>>.from(data['data'] ?? []);
        // Skip anything already on screen: a listing posted while you were
        // reading shifts the pages, which would otherwise repeat a card.
        final seen = current.vehicles.map((v) => v['_id']?.toString()).whereType<String>().toSet();
        final fresh = fetched.where((v) => !seen.contains(v['_id']?.toString())).toList();
        _page += 1;
        _hasMore = data['meta']?['hasNextPage'] ?? false;
        _loadingMore = false;
        emit(VehiclesLoaded(
          vehicles: [...current.vehicles, ...fresh],
          myAccepted: current.myAccepted,
          hasMore: _hasMore,
          currentPage: _page,
        ));
      },
    );
  }

  Future<void> _onRefresh(RefreshVehiclesEvent event, Emitter<VehiclesState> emit) async {
    final current = state;
    if (current is! VehiclesLoaded) return;

    final result = await repository.getVehicles(page: 1, filters: _filters);
    final myAcceptedResult = await repository.getAcceptedByMe();

    result.fold(
      // Background refresh: swallow errors, keep the current list.
      (_) {},
      (data) {
        final fetched = List<Map<String, dynamic>>.from(data['data'] ?? []);
        final myAccepted = myAcceptedResult.fold(
          (_) => current.myAccepted,
          (my) => List<Map<String, dynamic>>.from(my['data'] ?? []),
        );

        final fetchedById = {
          for (final m in fetched)
            if (m['_id'] != null) m['_id'].toString(): m,
        };
        final existingIds = current.vehicles
            .map((c) => c['_id']?.toString())
            .whereType<String>()
            .toSet();

        final updated = current.vehicles
            .map((c) => fetchedById[c['_id']?.toString()] ?? c)
            .toList();
        final newOnes = fetched.where((m) => !existingIds.contains(m['_id']?.toString())).toList();

        emit(VehiclesLoaded(
          vehicles: [...newOnes, ...updated],
          myAccepted: myAccepted,
          hasMore: current.hasMore,
          currentPage: current.currentPage,
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
