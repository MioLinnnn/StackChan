/*
SPDX-FileCopyrightText: 2026 M5Stack Technology CO LTD
SPDX-License-Identifier: MIT
*/

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../app_state.dart';
import '../model/msg_type.dart';
import '../util/debug_log_service.dart';
import '../util/rsa_util.dart';
import '../util/value_constant.dart';

class WebSocketUtil {
  WebSocketUtil._internal();

  static final WebSocketUtil shared = WebSocketUtil._internal();

  WebSocket? _socket;
  StreamSubscription? _subscription;

  bool _isConnected = false;

  final RxBool connectionStatus = false.obs;

  Function()? connectionSuccessful;

  final Map<String, void Function(dynamic)> _observers = {};

  String _urlString = '';

  String getAuthorization(String mac) {
    final rand = Random();
    final randomPart = List.generate(
      mac.length,
      (_) =>
          ValueConstant.characters[rand.nextInt(
            ValueConstant.characters.length,
          )],
    ).join();

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '$mac|$randomPart|$timestamp';
  }

  Future<void> connect(String urlString) async {
    if (_socket != null) {
      disconnect();
    }

    _urlString = urlString;

    if (AppState.shared.deviceMac.isEmpty) {
      DebugLogService.shared.warn('WS', 'Skipped: no deviceMac');
      _setConnectionState(false);
      return;
    }

    DebugLogService.shared.info('WS', 'Connecting $urlString');

    try {
      final encryptedToken = RsaUtil.encrypt(
        getAuthorization(AppState.shared.deviceMac),
      );
      final headers = {ValueConstant.authorization: encryptedToken};
      _socket = await WebSocket.connect(urlString, headers: headers);

      _setConnectionState(true);
      final connectTime = DateTime.now().toString().split('.').first;
      DebugLogService.shared.info('WS', 'Connected at $connectTime');

      _subscription = _socket!.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );

      connectionSuccessful?.call();
    } catch (e) {
      _setConnectionState(false);
      final errorTime = DateTime.now().toString().split('.').first;
      DebugLogService.shared.error('WS', 'Connect failed at $errorTime: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    final isPing = replyPong(message);
    if (!isPing) {
      _notifyObservers(message);
    }
  }

  void _handleError(Object error) {
    DebugLogService.shared.error('WS', 'Error: $error');
    _setConnectionState(false);
    _scheduleReconnect();
  }

  void _handleDone() {
    _setConnectionState(false);
    final closeTime = DateTime.now().toString().split('.').first;
    DebugLogService.shared.warn('WS', 'Closed at $closeTime, scheduling reconnect');
    _scheduleReconnect();
  }

  bool replyPong(dynamic message) {
    if (message is Uint8List) {
      final result = AppState.shared.parseMessage(message);
      final msgType = result.$1;

      if (msgType != null) {
        switch (msgType) {
          case MsgType.ping:
            AppState.shared.sendWebSocketMessage(.pong);
            return true;
          default:
            return false;
        }
      }
    }
    return false;
  }

  void sendString(String message) {
    if (_socket == null) {
      return;
    }

    try {
      _socket!.add(message);
    } catch (e) {
      DebugLogService.shared.error('WS', 'Send string failed: $e');
      _setConnectionState(false);
      _scheduleReconnect();
    }
  }

  void send(Uint8List data) {
    if (_socket == null) {
      return;
    }

    try {
      _socket!.add(data);
    } catch (e) {
      DebugLogService.shared.error('WS', 'Send failed: $e');
      _setConnectionState(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() async {
    if (_urlString.isEmpty) return;

    if (!_isConnected) {
      DebugLogService.shared.info('WS', 'Reconnecting...');
    }

    await Future.delayed(const Duration(seconds: 1));
    await connect(_urlString);
  }

  void disconnect() {
    _subscription?.cancel();
    _socket?.close(WebSocketStatus.goingAway, '主动断开连接');
    _setConnectionState(false);
    _socket = null;
    DebugLogService.shared.info('WS', 'Disconnected');
  }

  void addObserver(String key, void Function(dynamic message) observer) {
    _observers[key] = observer;
  }

  void removeObserver(String key) {
    _observers.remove(key);
  }

  void removeAllObservers() {
    _observers.clear();
  }

  void _notifyObservers(dynamic message) {
    for (final observer in _observers.values) {
      observer(message);
    }
  }

  bool get isConnected => _isConnected && _socket?.readyState == WebSocket.open;

  void _setConnectionState(bool connected) {
    _isConnected = connected;
    connectionStatus.value = connected && _socket?.readyState == WebSocket.open;
  }
}
