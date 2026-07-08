import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';

part 'subscription_event.dart';
part 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final ApiClient apiClient;

  SubscriptionBloc(this.apiClient) : super(SubscriptionInitial()) {
    on<LoadPlansEvent>(_onLoadPlans);
    on<CreateOrderEvent>(_onCreateOrder);
    on<VerifyPaymentEvent>(_onVerify);
    on<LoadMySubscriptionEvent>(_onLoadMy);
    on<TestActivateSubscriptionEvent>(_onTestActivate);
  }

  List<Map<String, dynamic>> _cachedPlans = [];

  Future<void> _onLoadPlans(LoadPlansEvent event, Emitter<SubscriptionState> emit) async {
    emit(SubscriptionLoading());
    try {
      final res = await apiClient.get('/subscriptions/plans');
      _cachedPlans = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
      emit(PlansLoaded(plans: _cachedPlans));
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
    }
  }

  Future<void> _onCreateOrder(CreateOrderEvent event, Emitter<SubscriptionState> emit) async {
    emit(SubscriptionLoading(cachedPlans: _cachedPlans));
    try {
      final res = await apiClient.post('/subscriptions/create-order/${event.planId}');
      emit(OrderCreated(orderData: res.data['data'] as Map<String, dynamic>, plans: _cachedPlans));
    } catch (e) {
      emit(SubscriptionError(message: e.toString(), cachedPlans: _cachedPlans));
    }
  }

  Future<void> _onVerify(VerifyPaymentEvent event, Emitter<SubscriptionState> emit) async {
    emit(SubscriptionLoading(cachedPlans: _cachedPlans));
    try {
      await apiClient.post('/subscriptions/verify-payment', data: event.paymentData);
      emit(PaymentVerified());
    } catch (e) {
      emit(SubscriptionError(message: e.toString(), cachedPlans: _cachedPlans));
    }
  }

  Future<void> _onLoadMy(LoadMySubscriptionEvent event, Emitter<SubscriptionState> emit) async {
    try {
      final res = await apiClient.get('/subscriptions/my');
      final subscription = res.data['data'] as Map<String, dynamic>?;
      
      // Save subscription to SharedPreferences for overlay access
      if (subscription != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('gora_user_subscription', jsonEncode(subscription));
        } catch (_) {}
      }
      
      emit(MySubscriptionLoaded(subscription: subscription));
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
    }
  }

  Future<void> _onTestActivate(TestActivateSubscriptionEvent event, Emitter<SubscriptionState> emit) async {
    emit(SubscriptionLoading(cachedPlans: _cachedPlans));
    try {
      await apiClient.post('/subscriptions/test-activate/${event.planId}');
      emit(PaymentVerified());
    } catch (e) {
      emit(SubscriptionError(message: e.toString(), cachedPlans: _cachedPlans));
    }
  }
}
