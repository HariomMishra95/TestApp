import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:testapp/Bloc/PriceBloc/Bloc.dart';
import 'package:testapp/Bloc/PriceBloc/Event.dart';
import 'package:testapp/Bloc/PriceBloc/State.dart';
import 'package:testapp/component/color.dart';

class PriceAlertScreen extends StatefulWidget {
  const PriceAlertScreen({Key? key}) : super(key: key);

  @override
  State<PriceAlertScreen> createState() => _PriceAlertScreenState();
}

class _PriceAlertScreenState extends State<PriceAlertScreen> {
  final _priceController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );
  bool _hasInternet = false;

  @override
  void initState() {
    super.initState();
    // Check connectivity first, then connect
    _checkConnectivity();

    // Also initiate the connection attempt (the bloc will handle internet check)
    context.read<PriceBloc>().add(ConnectWebSocket());
  }

  void _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = connectivityResult != ConnectivityResult.none;
    });

    debugPrint('Internet connectivity status: $_hasInternet');

    // Subscribe to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      setState(() {
        _hasInternet = isConnected;
      });
      debugPrint('Internet connectivity changed: $isConnected');
    });
  }

  void _setAlert() {
    final inputText = _priceController.text.trim();
    if (inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    try {
      final price = double.parse(inputText);
      context.read<PriceBloc>().add(SetAlertPrice(price));
      _priceController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid price format. Please enter a number.')),
      );
    }
  }

  void _resetAlert() {
    context.read<PriceBloc>().add(ClearAlert());
  }

  void _reconnectWebSocket() {
    context.read<PriceBloc>().add(ConnectWebSocket());
  }

  void _playAlertSound() async {
    try {
      await _audioPlayer.setSource(AssetSource('sound/alert.mp3'));
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Error playing alert sound: $e');
    }
  }

  bool _alertSoundPlayed = false;

  @override
  void dispose() {
    _priceController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: filter3,
        title: Text(
          'BTC/USDT Price Alert',
          style: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          // Add debug button to manually trigger connection
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _reconnectWebSocket,
            tooltip: 'Force Reconnect',
          ),
        ],
      ),
      body: BlocConsumer<PriceBloc, PriceState>(
        listener: (context, state) {
          // Log state changes to help debugging
          // debugPrint('PriceBloc state changed: ${state.runtimeType}');

          if (state is PriceConnected) {
            if (state.isAlertSet &&
                state.isAlertTriggered &&
                !_alertSoundPlayed) {
              _playAlertSound();
              _alertSoundPlayed = true; // Prevent replay
            }

            // Reset flag if alert is cleared or reset
            if (!state.isAlertTriggered) {
              _alertSoundPlayed = false;
            }
          } else {
            // Reset sound flag when disconnected
            _alertSoundPlayed = false;
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  _buildPriceDisplay(state),
                  const SizedBox(height: 30),
                  _buildConnectionStatus(state),
                  const SizedBox(height: 30),
                  _buildAlertInput(state),
                  const SizedBox(height: 30),
                  _buildAlertStatus(state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus(PriceState state) {
    bool isConnected = state is PriceConnected;
    bool isReconnecting = state is PriceDisconnected && (state).isReconnecting;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withOpacity(0.2)
            : isReconnecting
                ? Colors.amber.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected
                ? Icons.wifi
                : isReconnecting
                    ? Icons.sync
                    : Icons.wifi_off,
            color: isConnected
                ? Colors.green
                : isReconnecting
                    ? Colors.amber
                    : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            isConnected
                ? 'Connected'
                : isReconnecting
                    ? 'Reconnecting...'
                    : 'Disconnected',
            style: TextStyle(
              color: isConnected
                  ? Colors.green
                  : isReconnecting
                      ? Colors.amber
                      : Colors.red,
            ),
          ),
          if (!isConnected && !isReconnecting) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _reconnectWebSocket,
              child: const Text('Reconnect'),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceDisplay(PriceState state) {
    double currentPrice = 0.0;
    if (state is PriceConnected) {
      currentPrice = state.currentPrice;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: filter3
        )
      ),
      color: filter3.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Live BTC/USDT Mark Price',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              currentPrice > 0
                  ? _currencyFormat.format(currentPrice)
                  : 'Loading...',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertInput(PriceState state) {
    final isConnected = state is PriceConnected;
    final isAlertSet = isConnected && (state as PriceConnected).isAlertSet;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 54,
                padding: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Set Alert Price (e.g., 43000)',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isConnected ? _setAlert : null,
                icon: const Icon(
                  Icons.add_alert,
                  color: Colors.white,
                ),
                label: const Text(
                  'Set Alert',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: filter3,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (isAlertSet) ...[
              const SizedBox(width: 10),
              IconButton(
                onPressed: _resetAlert,
                icon: const Icon(
                  Icons.cancel,
                  color: filter3,
                ),
                tooltip: 'Clear Alert',
                color: Colors.red,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAlertStatus(PriceState state) {
    String statusText = '';
    Color statusColor = Colors.grey;

    if (state is PriceConnected) {
      if (state.isAlertTriggered) {
        statusText =
            'Alert triggered! Price reached ${_currencyFormat.format(state.alertPrice)}';
        statusColor = Colors.green;
      } else if (state.isAlertSet) {
        statusText =
            'Waiting for price to reach ${_currencyFormat.format(state.alertPrice)}...';
        statusColor = Colors.amber;
      } else {
        statusText = 'No price alert set';
      }
    } else if (state is PriceDisconnected) {
      statusText = state.isReconnecting
          ? 'Connection lost. Attempting to reconnect...'
          : state.error;
      statusColor = state.isReconnecting ? Colors.amber : Colors.red;
    } else if (state is PriceLoading) {
      statusText = 'Connecting to Binance...';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(state),
            color: statusColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: state is PriceConnected && state.isAlertTriggered
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(PriceState state) {
    if (state is PriceConnected) {
      if (state.isAlertTriggered) {
        return Icons.check_circle;
      } else if (state.isAlertSet) {
        return Icons.notifications_active;
      }
    } else if (state is PriceLoading) {
      return Icons.sync;
    } else if (state is PriceDisconnected) {
      return state.isReconnecting ? Icons.sync : Icons.error_outline;
    }
    return Icons.info_outline;
  }
}
