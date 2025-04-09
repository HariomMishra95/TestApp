import 'package:equatable/equatable.dart';

abstract class PriceEvent extends Equatable {
  const PriceEvent();

  @override
  List<Object?> get props => [];
}

class ConnectWebSocket extends PriceEvent {}

class DisconnectWebSocket extends PriceEvent {}

class SetAlertPrice extends PriceEvent {
  final double price;

  const SetAlertPrice(this.price);

  @override
  List<Object?> get props => [price];
}

class ClearAlert extends PriceEvent {}

class ReceivePrice extends PriceEvent {
  final double price;

  const ReceivePrice(this.price);

  @override
  List<Object?> get props => [price];
}

class AlertTriggered extends PriceEvent {}

class ReconnectWebSocket extends PriceEvent {}

class ConnectionError extends PriceEvent {
  final String message;

  const ConnectionError(this.message);

  @override
  List<Object?> get props => [message];
}

class InternetConnectivityChanged extends PriceEvent {
  final bool isConnected;

  const InternetConnectivityChanged(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}
