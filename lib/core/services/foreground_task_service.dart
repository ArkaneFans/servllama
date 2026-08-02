import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 前台任务回调函数。
/// 必须是顶级函数，并使用 @pragma('vm:entry-point') 注解。
@pragma('vm:entry-point')
void foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_LlamaServerTaskHandler());
}

/// 前台任务处理器。
/// 在独立的 Dart isolate 中运行，仅保持前台服务存活。
class _LlamaServerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // llama-server 进程由 LlamaServerService 在主 isolate 中管理
    // 此处无需额外操作，仅保持前台服务运行
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 可选：向主 isolate 发送心跳
    FlutterForegroundTask.sendDataToMain({
      'type': 'heartbeat',
      'timestamp': timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // 清理资源（如有需要）
  }
}

/// 前台服务封装类。
/// 用于管理 Android 前台服务，保持应用在后台时进程不被终止。
class ForegroundTaskService {
  static final ForegroundTaskService _instance =
      ForegroundTaskService._internal();
  factory ForegroundTaskService() => _instance;
  ForegroundTaskService._internal();

  static const int _serviceId = 256;
  static const String _channelId = 'llama_server_foreground';
  static const String _channelName = 'Llama Server Service';
  static const String _channelDescription = '保持 llama-server 在后台运行';
  static const String serverOwner = 'server';
  static const String downloadsOwner = 'downloads';

  final Map<String, ({String title, String text})> _owners =
      <String, ({String title, String text})>{};
  bool _initialized = false;

  /// 初始化前台任务配置。
  /// 必须在使用前调用一次。
  void init() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription: _channelDescription,
        onlyAlertOnce: true,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // 监听来自 TaskHandler 的数据
    FlutterForegroundTask.addTaskDataCallback(_handleData);
  }

  void _handleData(Object data) {
    // 处理来自 TaskHandler 的数据（可选）
  }

  /// 检查前台服务是否正在运行。
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// 启动前台服务。
  /// 返回是否启动成功。
  Future<bool> start({
    required String notificationTitle,
    required String notificationText,
  }) => acquire(
    owner: serverOwner,
    notificationTitle: notificationTitle,
    notificationText: notificationText,
  );

  Future<bool> acquire({
    required String owner,
    required String notificationTitle,
    required String notificationText,
  }) async {
    _owners[owner] = (title: notificationTitle, text: notificationText);
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await _publishCurrentNotification();
        return true;
      }
      final current = _currentNotification;
      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: current.title,
        notificationText: current.text,
        notificationInitialRoute: '/',
        callback: foregroundTaskCallback,
      );
      return result is ServiceRequestSuccess;
    } catch (e) {
      _owners.remove(owner);
      return false;
    }
  }

  /// 更新通知内容。
  Future<void> updateNotification({
    required String title,
    required String text,
  }) => updateOwner(owner: serverOwner, title: title, text: text);

  Future<void> updateOwner({
    required String owner,
    required String title,
    required String text,
  }) async {
    if (!_owners.containsKey(owner)) {
      return;
    }
    _owners[owner] = (title: title, text: text);
    await _publishCurrentNotification();
  }

  /// 停止前台服务。
  /// 返回是否停止成功。
  Future<bool> stop() => release(serverOwner);

  Future<bool> release(String owner) async {
    _owners.remove(owner);
    if (_owners.isNotEmpty) {
      try {
        await _publishCurrentNotification();
        return true;
      } catch (_) {
        return false;
      }
    }
    try {
      final result = await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    } catch (e) {
      return false;
    }
  }

  ({String title, String text}) get _currentNotification {
    return _owners[downloadsOwner] ??
        _owners[serverOwner] ??
        _owners.values.last;
  }

  Future<void> _publishCurrentNotification() async {
    if (_owners.isEmpty || !await FlutterForegroundTask.isRunningService) {
      return;
    }
    final current = _currentNotification;
    await FlutterForegroundTask.updateService(
      notificationTitle: current.title,
      notificationText: current.text,
    );
  }

  void dispose() {
    _owners.clear();
    FlutterForegroundTask.removeTaskDataCallback(_handleData);
  }
}
