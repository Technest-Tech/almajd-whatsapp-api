import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';

class WebSocketsClient {
  static final WebSocketsClient instance = WebSocketsClient._internal();
  PusherChannelsClient? pusher;
  bool _isInitialized = false;

  WebSocketsClient._internal();

  Future<void> init(FlutterSecureStorage storage) async {
    if (_isInitialized) return;

    final token = await storage.read(key: 'access_token');
    
    // For dart_pusher_channels, we provide the exact WS or WSS URL, resolving host issues completely
    const hostOptions = PusherChannelsOptions.fromHost(
      scheme: 'wss',
      host: 'cloud.almajd.info',
      port: 443,
      key: 'almajd_app_key',
    );

    pusher = PusherChannelsClient.websocket(
      options: hostOptions,
      connectionErrorHandler: (exception, trace, refresh) {
        print('Pusher Connection Error: $exception');
        refresh();
      },
    );

    pusher?.onConnectionEstablished.listen((_) {
      print("WebSocket connected to Reverb!");
    });
      
    pusher?.connect();
    _isInitialized = true;
  }

  void disconnect() {
    pusher?.disconnect();
    pusher = null;
    _isInitialized = false;
  }
}


