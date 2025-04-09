import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testapp/Bloc/PriceBloc/Event.dart';
import 'package:testapp/Bloc/PriceBloc/State.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:connectivity_plus/connectivity_plus.dart';

class PriceBloc extends Bloc<PriceEvent, PriceState> {
  final String _wsUrl = 'wss://fstream.binance.com/ws/btcusdt@markPrice';
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  bool _manuallyDisconnected = false;
  bool _hasInternet = false;
  double _lastPrice = 0.0;
  double? _lastAlertPrice;
  bool _lastIsAlertSet = false;
  bool _lastIsAlertTriggered = false;

  PriceBloc() : super(PriceInitial()) {
    on<ConnectWebSocket>(_onConnectWebSocket);
    on<DisconnectWebSocket>(_onDisconnectWebSocket);
    on<ReceivePrice>(_onReceivePrice);
    on<SetAlertPrice>(_onSetAlertPrice);
    on<ClearAlert>(_onClearAlert);
    on<AlertTriggered>(_onAlertTriggered);
    on<ReconnectWebSocket>(_onReconnectWebSocket);
    on<ConnectionError>(_onConnectionError);
    on<InternetConnectivityChanged>(_onInternetConnectivityChanged);
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      add(InternetConnectivityChanged(isConnected));
    });

    Connectivity().checkConnectivity().then((result) {
      final isConnected = result != ConnectivityResult.none;
      add(InternetConnectivityChanged(isConnected));
    });
  }

  void _onInternetConnectivityChanged(
      InternetConnectivityChanged event, Emitter<PriceState> emit) {
    _hasInternet = event.isConnected;
    if (_hasInternet && (state is! PriceConnected) && !_manuallyDisconnected) {
      add(ConnectWebSocket());
    } else if (!_hasInternet && (state is PriceConnected)) {
      emit(const PriceDisconnected(
          error: 'Internet connection lost', isReconnecting: true));
    }
  }

  Future<void> _onConnectWebSocket(
      ConnectWebSocket event, Emitter<PriceState> emit) async {
    if (!_hasInternet) {
      emit(const PriceDisconnected(
          error: 'No internet connection available', isReconnecting: true));
      return;
    }

    if (_channel != null) {
      await _disconnectWebSocket(emitState: false);
    }

    emit(PriceLoading());
    _manuallyDisconnected = false;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _subscription = _channel!.stream.listen(
        (message) {
          _reconnectAttempts = 0;

          try {
            final data = jsonDecode(message);
            if (data.containsKey('p')) {
              final price = double.parse(data['p']);
              add(ReceivePrice(price));
            }
          } catch (e) {
            add(ConnectionError('Failed to parse message: $e'));
          }
        },
        onError: (error) {
          add(ConnectionError('WebSocket error: $error'));
        },
        onDone: () {
          if (!_manuallyDisconnected) {
            add(ConnectionError('WebSocket connection closed unexpectedly'));
          }
        },
      );
      if (_lastPrice > 0) {
        emit(PriceConnected(
          currentPrice: _lastPrice,
          alertPrice: _lastAlertPrice,
          isAlertSet: _lastIsAlertSet,
          isAlertTriggered: _lastIsAlertTriggered,
        ));
      } else {
        emit(const PriceConnected(currentPrice: 0.0));
      }
    } catch (e) {
      add(ConnectionError('Failed to connect: $e'));
    }
  }

  void _onConnectionError(ConnectionError event, Emitter<PriceState> emit) {
    if (state is PriceConnected) {
      final currentState = state as PriceConnected;
      _lastPrice = currentState.currentPrice;
      _lastAlertPrice = currentState.alertPrice;
      _lastIsAlertSet = currentState.isAlertSet;
      _lastIsAlertTriggered = currentState.isAlertTriggered;
    }

    emit(PriceDisconnected(error: event.message, isReconnecting: true));
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Implement exponential backoff for reconnection attempts
    if (_reconnectAttempts < _maxReconnectAttempts &&
        !_manuallyDisconnected &&
        _hasInternet) {
      final delay = _calculateBackoffDelay(_reconnectAttempts);
      _reconnectAttempts++;

      _reconnectTimer = Timer(Duration(milliseconds: delay), () {
        add(ReconnectWebSocket());
      });
    }
  }

  int _calculateBackoffDelay(int attempt) {
    return 1000 * (1 << attempt);
  }

  Future<void> _onDisconnectWebSocket(
      DisconnectWebSocket event, Emitter<PriceState> emit) async {
    _manuallyDisconnected = true;
    await _disconnectWebSocket(emitState: true);
    emit(const PriceDisconnected(error: 'Manually disconnected'));
  }

  Future<void> _disconnectWebSocket({bool emitState = true}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _channel?.sink.close(status.goingAway);
    } catch (e) {}
    _channel = null;
  }

  void _onReceivePrice(ReceivePrice event, Emitter<PriceState> emit) {
    _lastPrice = event.price;

    if (state is PriceConnected) {
      final currentState = state as PriceConnected;
      final newState = currentState.copyWith(currentPrice: event.price);
      if (newState.isAlertSet &&
          !newState.isAlertTriggered &&
          newState.alertPrice != null) {
        final alertPrice = newState.alertPrice!;

        if ((alertPrice >= event.price && event.price > alertPrice - 50) ||
            (alertPrice <= event.price && event.price < alertPrice + 50)) {
          add(AlertTriggered());
          return;
        }
      }

      emit(newState);
    } else {
      emit(PriceConnected(currentPrice: event.price));
    }
  }

  void _onSetAlertPrice(SetAlertPrice event, Emitter<PriceState> emit) {
    _lastAlertPrice = event.price;
    _lastIsAlertSet = true;
    _lastIsAlertTriggered = false;

    if (state is PriceConnected) {
      final currentState = state as PriceConnected;
      emit(currentState.copyWith(
        alertPrice: event.price,
        isAlertSet: true,
        isAlertTriggered: false,
      ));
    }
  }

  void _onClearAlert(ClearAlert event, Emitter<PriceState> emit) {
    _lastIsAlertSet = false;
    _lastIsAlertTriggered = false;

    if (state is PriceConnected) {
      final currentState = state as PriceConnected;
      emit(currentState.copyWith(
        isAlertSet: false,
        isAlertTriggered: false,
      ));
    }
  }

  void _onAlertTriggered(AlertTriggered event, Emitter<PriceState> emit) {
    _lastIsAlertTriggered = true;

    if (state is PriceConnected) {
      final currentState = state as PriceConnected;
      emit(currentState.copyWith(isAlertTriggered: true));
    }
  }

  void _onReconnectWebSocket(
      ReconnectWebSocket event, Emitter<PriceState> emit) {
    add(ConnectWebSocket());
  }

  @override
  Future<void> close() {
    _manuallyDisconnected = true;
    _disconnectWebSocket();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
