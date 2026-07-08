/*
SPDX-FileCopyrightText: 2026 M5Stack Technology CO LTD
SPDX-License-Identifier: MIT
*/

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stack_chan/app_state.dart';
import 'package:stack_chan/network/http.dart';
import 'package:stack_chan/network/urls.dart';
import 'package:stack_chan/network/web_socket_util.dart';
import 'package:stack_chan/util/debug_log_service.dart';
import 'package:stack_chan/util/value_constant.dart';

enum _HttpProbeStatus { checking, ok, error, skipped }

enum _LogFilter { all, http, ws }

class DebugPanelPage extends StatefulWidget {
  const DebugPanelPage({super.key});

  @override
  State<DebugPanelPage> createState() => _DebugPanelPageState();
}

class _DebugPanelPageState extends State<DebugPanelPage> {
  _HttpProbeStatus _httpStatus = _HttpProbeStatus.checking;
  String _httpStatusLabel = 'Checking...';
  _LogFilter _logFilter = _LogFilter.all;

  @override
  void initState() {
    super.initState();
    _probeHttp();
  }

  Future<void> _probeHttp() async {
    if (!AppState.shared.hasValidDeviceMac) {
      setState(() {
        _httpStatus = _HttpProbeStatus.skipped;
        _httpStatusLabel = 'No device bound';
      });
      return;
    }

    setState(() {
      _httpStatus = _HttpProbeStatus.checking;
      _httpStatusLabel = 'Checking...';
    });

    try {
      final map = {ValueConstant.mac: AppState.shared.deviceMac};
      await Http.instance.get(Urls.deviceInfo, data: map);
      if (!mounted) return;
      setState(() {
        _httpStatus = _HttpProbeStatus.ok;
        _httpStatusLabel = 'Reachable';
      });
      DebugLogService.shared.info('APP', 'HTTP probe succeeded');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _httpStatus = _HttpProbeStatus.error;
        _httpStatusLabel = 'Failed (${e.response?.statusCode ?? e.type})';
      });
      DebugLogService.shared.error('APP', 'HTTP probe failed: $e');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _httpStatus = _HttpProbeStatus.error;
        _httpStatusLabel = 'Failed';
      });
      DebugLogService.shared.error('APP', 'HTTP probe failed: $e');
    }
  }

  void _copyText(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppState.shared.showToast('Copied $label');
  }

  void _copyAllLogs() {
    final text = DebugLogService.shared.exportAll();
    if (text.isEmpty) {
      AppState.shared.showToast('No logs');
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    AppState.shared.showToast('Logs copied');
  }

  List<DebugLogEntry> _filteredLogs() {
    final logs = DebugLogService.shared.logs;
    switch (_logFilter) {
      case _LogFilter.http:
        return logs.where((e) => e.tag == 'HTTP').toList().reversed.toList();
      case _LogFilter.ws:
        return logs.where((e) => e.tag == 'WS').toList().reversed.toList();
      case _LogFilter.all:
        return logs.reversed.toList();
    }
  }

  Color _statusColor(bool? active, {bool unknown = false}) {
    if (unknown) return CupertinoColors.systemGrey;
    if (active == true) return CupertinoColors.systemGreen;
    return CupertinoColors.systemRed;
  }

  Color _httpStatusColor() {
    switch (_httpStatus) {
      case _HttpProbeStatus.ok:
        return CupertinoColors.systemGreen;
      case _HttpProbeStatus.error:
        return CupertinoColors.systemRed;
      case _HttpProbeStatus.skipped:
        return CupertinoColors.systemGrey;
      case _HttpProbeStatus.checking:
        return CupertinoColors.systemGrey2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsPreview =
        '${Urls.getWebSocketUrl()}?deviceType=App&deviceId=${AppState.shared.deviceId}';

    return ClipRSuperellipse(
      borderRadius: .circular(12),
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
          context,
        ),
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Debug Panel'),
          trailing: CupertinoButton(
            padding: .zero,
            onPressed: () => Navigator.pop(context),
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 25,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    CupertinoListSection.insetGrouped(
                      header: const Text('Server'),
                      children: [
                        _urlTile(context, 'HTTP API', Urls.getBaseUrl()),
                        _urlTile(context, 'WebSocket', wsPreview),
                        _urlTile(context, 'File URL', Urls.getFileUrl()),
                        _urlTile(context, 'XiaoZhi API', 'https://XiaoZhi.me/'),
                      ],
                    ),
                    CupertinoListSection.insetGrouped(
                      header: const Text('Connection'),
                      children: [
                        Padding(
                          padding: const .symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: CupertinoButton.filled(
                            padding: const .symmetric(vertical: 10),
                            onPressed: () {
                              AppState.shared.connectWebSocket();
                              _probeHttp();
                            },
                            child: const Text('Reconnect WebSocket'),
                          ),
                        ),
                        Obx(
                          () => _statusTile(
                            'User logged in',
                            AppState.shared.isLogin.value,
                            AppState.shared.isLogin.value
                                ? 'Logged in'
                                : 'Not logged in',
                          ),
                        ),
                        Obx(
                          () => _statusTile(
                            'Device bound',
                            AppState.shared.hasValidDeviceMac,
                            AppState.shared.hasValidDeviceMac
                                ? AppState.shared.deviceMac
                                : 'No device',
                          ),
                        ),
                        Obx(
                          () => _statusTile(
                            'WebSocket',
                            WebSocketUtil.shared.connectionStatus.value,
                            WebSocketUtil.shared.connectionStatus.value
                                ? 'Connected'
                                : 'Disconnected',
                          ),
                        ),
                        Obx(
                          () => _statusTile(
                            'Device online',
                            AppState.shared.deviceIsOnline,
                            AppState.shared.deviceIsOnline
                                ? 'Online'
                                : 'Offline',
                          ),
                        ),
                        _statusTile(
                          'HTTP reachable',
                          _httpStatus == _HttpProbeStatus.ok,
                          _httpStatusLabel,
                          dotColor: _httpStatusColor(),
                          unknown: _httpStatus == _HttpProbeStatus.checking,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const .fromLTRB(20, 8, 20, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Logs',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: .zero,
                            minimumSize: Size.zero,
                            onPressed: () => setState(
                              () => _logFilter = _LogFilter.all,
                            ),
                            child: Text(
                              'ALL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _logFilter == _LogFilter.all
                                    ? .bold
                                    : .normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CupertinoButton(
                            padding: .zero,
                            minimumSize: Size.zero,
                            onPressed: () => setState(
                              () => _logFilter = _LogFilter.http,
                            ),
                            child: Text(
                              'HTTP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _logFilter == _LogFilter.http
                                    ? .bold
                                    : .normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CupertinoButton(
                            padding: .zero,
                            minimumSize: Size.zero,
                            onPressed: () => setState(
                              () => _logFilter = _LogFilter.ws,
                            ),
                            child: Text(
                              'WS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _logFilter == _LogFilter.ws
                                    ? .bold
                                    : .normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() {
                      final entries = _filteredLogs();
                      if (entries.isEmpty) {
                        return const Padding(
                          padding: .all(24),
                          child: Center(
                            child: Text(
                              'No logs yet',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final color = switch (entry.level) {
                            DebugLogLevel.error => CupertinoColors.systemRed,
                            DebugLogLevel.warn =>
                              CupertinoColors.systemOrange,
                            DebugLogLevel.info => null,
                          };
                          return Padding(
                            padding: const .symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            child: Text(
                              entry.line,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: color,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  border: Border(
                    top: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                  ),
                ),
                padding: const .symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const .symmetric(vertical: 10),
                        color: CupertinoColors.systemGrey5.resolveFrom(context),
                        onPressed: DebugLogService.shared.clear,
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton.filled(
                        padding: const .symmetric(vertical: 10),
                        onPressed: _copyAllLogs,
                        child: const Text('Copy All'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _urlTile(BuildContext context, String label, String value) {
    return CupertinoListTile(
      title: Text(label),
      subtitle: Text(
        value,
        maxLines: 3,
        overflow: .ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: CupertinoButton(
        padding: .zero,
        minimumSize: Size.zero,
        onPressed: () => _copyText(label, value),
        child: const Icon(CupertinoIcons.doc_on_doc, size: 18),
      ),
    );
  }

  Widget _statusTile(
    String title,
    bool? active,
    String subtitle, {
    Color? dotColor,
    bool unknown = false,
  }) {
    final color = dotColor ?? _statusColor(active, unknown: unknown);
    return CupertinoListTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: .circle),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
