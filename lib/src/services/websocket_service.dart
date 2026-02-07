import 'dart:async';
import 'dart:convert';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';

import '../models/chat_message.dart';

typedef VoidCallback = void Function();

class WebSocketService {
  PusherChannelsClient? _client;
  StreamSubscription? _connectionSub;
  StreamSubscription? _eventSub;
  bool _connected = false;

  final void Function(ChatMessage message)? onMessage;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final void Function(dynamic error)? onError;

  WebSocketService({
    this.onMessage,
    this.onConnected,
    this.onDisconnected,
    this.onError,
  });

  bool get isConnected => _connected;

  /// Connect to Laravel Reverb WebSocket server
  Future<bool> connect({
    required String host,
    required int port,
    required String appKey,
    String scheme = 'wss',
  }) async {
    try {
      final options = PusherChannelsOptions.fromHost(
        scheme: scheme,
        host: host,
        key: appKey,
        port: port,
        shouldSupplyMetadataQueries: true,
        metadata: PusherChannelsOptionsMetadata.byDefault(),
      );

      _client = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          _connected = false;
          onError?.call(exception);
          // Try to reconnect after error
          Future.delayed(const Duration(seconds: 3), () {
            refresh();
          });
        },
        minimumReconnectDelayDuration: const Duration(seconds: 1),
        defaultActivityDuration: const Duration(seconds: 120),
      );

      _connectionSub = _client!.onConnectionEstablished.listen((_) {
        _connected = true;
        onConnected?.call();
      });

      _client!.connect();
      return true;
    } catch (e) {
      _connected = false;
      onError?.call(e);
      return false;
    }
  }

  /// Subscribe to widget channel for receiving messages
  void subscribe(String widgetId, String sessionId) {
    if (_client == null) return;

    final channelName = 'widget.$widgetId.$sessionId';

    try {
      final channel = _client!.publicChannel(channelName);

      // Subscribe when connected
      _connectionSub?.cancel();
      _connectionSub = _client!.onConnectionEstablished.listen((_) {
        _connected = true;
        onConnected?.call();
        channel.subscribeIfNotUnsubscribed();
      });

      // Also subscribe immediately if already connected
      if (_connected) {
        channel.subscribeIfNotUnsubscribed();
      }

      // Listen for message.sent events (matches Laravel WidgetMessageSent event)
      _eventSub?.cancel();
      _eventSub = channel.bind('.message.sent').listen((event) {
        if (onMessage != null) {
          try {
            final data = event.data;
            if (data != null) {
              final messageData = data is String ? jsonDecode(data) : data;
              if (messageData is Map<String, dynamic>) {
                final message = ChatMessage.fromJson(messageData);
                onMessage!(message);
              }
            }
          } catch (_) {
            // Silently ignore malformed messages
          }
        }
      });
    } catch (e) {
      onError?.call(e);
    }
  }

  /// Disconnect and clean up
  void disconnect() {
    _connectionSub?.cancel();
    _connectionSub = null;
    _eventSub?.cancel();
    _eventSub = null;

    try {
      _client?.dispose();
    } catch (_) {}

    _client = null;
    _connected = false;
  }
}
