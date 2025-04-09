import 'package:equatable/equatable.dart';

abstract class PriceState extends Equatable {
  const PriceState();

  @override
  List<Object?> get props => [];
}

class PriceInitial extends PriceState {}

class PriceLoading extends PriceState {}

class PriceConnected extends PriceState {
  final double currentPrice;
  final double? alertPrice;
  final bool isAlertSet;
  final bool isAlertTriggered;

  const PriceConnected({
    required this.currentPrice,
    this.alertPrice,
    this.isAlertSet = false,
    this.isAlertTriggered = false,
  });

  PriceConnected copyWith({
    double? currentPrice,
    double? alertPrice,
    bool? isAlertSet,
    bool? isAlertTriggered,
  }) {
    return PriceConnected(
      currentPrice: currentPrice ?? this.currentPrice,
      alertPrice: alertPrice ?? this.alertPrice,
      isAlertSet: isAlertSet ?? this.isAlertSet,
      isAlertTriggered: isAlertTriggered ?? this.isAlertTriggered,
    );
  }

  @override
  List<Object?> get props =>
      [currentPrice, alertPrice, isAlertSet, isAlertTriggered];
}

class PriceDisconnected extends PriceState {
  final String error;
  final bool isReconnecting;

  const PriceDisconnected({
    this.error = 'Disconnected from WebSocket',
    this.isReconnecting = false,
  });

  @override
  List<Object?> get props => [error, isReconnecting];
}
