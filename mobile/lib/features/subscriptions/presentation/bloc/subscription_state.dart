part of 'subscription_bloc.dart';

abstract class SubscriptionState extends Equatable {
  const SubscriptionState();
  @override
  List<Object?> get props => [];
}

class SubscriptionInitial extends SubscriptionState {}
class SubscriptionLoading extends SubscriptionState {}

class PlansLoaded extends SubscriptionState {
  final List<Map<String, dynamic>> plans;
  const PlansLoaded({required this.plans});
  @override
  List<Object?> get props => [plans];
}

class OrderCreated extends SubscriptionState {
  final Map<String, dynamic> orderData;
  const OrderCreated({required this.orderData});
  @override
  List<Object?> get props => [orderData];
}

class PaymentVerified extends SubscriptionState {}

class MySubscriptionLoaded extends SubscriptionState {
  final Map<String, dynamic>? subscription;
  const MySubscriptionLoaded({this.subscription});
  @override
  List<Object?> get props => [subscription];
}

class SubscriptionError extends SubscriptionState {
  final String message;
  const SubscriptionError({required this.message});
  @override
  List<Object?> get props => [message];
}
