import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:src/model/model.dart';
import 'package:src/utils/constants/constants.dart';

class ViewModel {
  static ViewModel? _instance;
  WebSocketChannel? _channel;
  StreamController<Model>? _dataController;
  Model? _latestData;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _activeWsUrl;
  Timer? _reconnectTimer;

  // Singleton pattern
  factory ViewModel() {
    _instance ??= ViewModel._internal();
    _instance!._ensureDataController();
    return _instance!;
  }

  ViewModel._internal() {
    _ensureDataController();
    if (ConnectionConfig.hasSelection) {
      connectWithSelectedMode();
    }
  }

  void _ensureDataController() {
    if (_dataController == null || _dataController!.isClosed) {
      _dataController = StreamController<Model>.broadcast();
    }
  }

  // Connect using currently selected mode.
  void connectWithSelectedMode() {
    if (!ConnectionConfig.hasSelection) {
      if (kDebugMode) {
        print('Connection mode is not selected yet.');
      }
      return;
    }
    connectWithUrl(Constants.wsUrl);
  }

  // Connect using an explicit WebSocket URL.
  void connectWithUrl(String wsUrl) {
    if (wsUrl.isEmpty) return;
    _activeWsUrl = wsUrl;
    _connect();
  }

  // Connect to WebSocket.
  void _connect() {
    if (_isConnected || _isConnecting || _activeWsUrl == null) return;

    try {
      _isConnecting = true;
      if (kDebugMode) {
        print('Connecting to WebSocket: $_activeWsUrl');
      }

      _channel = WebSocketChannel.connect(
        Uri.parse(_activeWsUrl!),
      );

      _isConnected = true;
      _isConnecting = false;

      // Listen to incoming messages
      _channel!.stream.listen(
        (message) {
          try {
            if (kDebugMode) {
              print('Received WebSocket message: $message');
            }

            final jsonData = jsonDecode(message);
            if (jsonData != null && jsonData is Map<String, dynamic>) {
              final model = Model.fromJson(jsonData);
              _latestData = model;
              _dataController?.add(model);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing WebSocket message: $e');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('WebSocket error: $error');
          }
          _handleDisconnect();
        },
        onDone: () {
          if (kDebugMode) {
            print('WebSocket connection closed');
          }
          _handleDisconnect();
        },
      );

      // Cancel any existing reconnect timer
      _reconnectTimer?.cancel();
    } catch (e) {
      _isConnecting = false;
      if (kDebugMode) {
        print('Failed to connect to WebSocket: $e');
      }
      _handleDisconnect();
    }
  }

  // Handle disconnection and attempt reconnect
  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _channel = null;

    // Attempt to reconnect after 3 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (kDebugMode) {
        print('Attempting to reconnect to WebSocket...');
      }
      _connect();
    });
  }

  // Get stream of data updates
  Stream<Model> get dataStream => _dataController!.stream;

  // Get latest data (for backward compatibility with existing API)
  static Future<Model> fetchWorldStates(String type) async {
    final instance = ViewModel();

    // If we already have data, return it immediately
    if (instance._latestData != null) {
      return instance._latestData!;
    }

    // Otherwise, wait for the first data from the stream
    try {
      final model = await instance.dataStream.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout waiting for data from WebSocket');
        },
      );
      return model;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
      throw Exception('Failed to fetch data: $e');
    }
  }

  // Get latest cached data synchronously
  Model? get latestData => _latestData;

  // Check if connected
  bool get isConnected => _isConnected;

  // Close connection
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _dataController?.close();
    _isConnected = false;
    _isConnecting = false;
    _activeWsUrl = null;
  }

  // Force reconnect
  void reconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _isConnecting = false;
    _connect();
  }
}
