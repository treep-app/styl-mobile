import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import '../network/api_models.dart';
import '../../features/customer/data/notifications_api.dart';

/// Live inbox sync for customers and salon owners.
///
/// Polls while logged in so both sides see new booking alerts without push.
class NotificationController extends ChangeNotifier {
  NotificationController(this._auth) {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthController _auth;

  Timer? _timer;
  var _busy = false;
  var unreadCount = 0;
  List<NotificationDto> items = const [];
  String? _latestId;
  NotificationDto? latestAlert;

  NotificationsApi get _api => _auth.notificationsApi;

  void _onAuthChanged() {
    if (_auth.isLoggedIn) {
      start();
    } else {
      stop();
      unreadCount = 0;
      items = const [];
      _latestId = null;
      latestAlert = null;
      notifyListeners();
    }
  }

  void start() {
    _timer?.cancel();
    unawaited(refresh(silent: true));
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(refresh(silent: true));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh({bool silent = false}) async {
    if (!_auth.isLoggedIn || _busy) return;
    _busy = true;
    try {
      final results = await Future.wait([
        _api.list(),
        _api.unreadCount(),
      ]);
      final list = results[0] as List<NotificationDto>;
      final count = results[1] as int;

      NotificationDto? alert;
      if (list.isNotEmpty) {
        final head = list.first;
        if (_latestId != null && head.id != _latestId && head.unread) {
          alert = head;
        }
        _latestId = head.id;
      }

      unreadCount = count;
      items = list;
      latestAlert = alert;
      notifyListeners();
    } catch (e) {
      if (kDebugMode && !silent) {
        debugPrint('Notification refresh failed: $e');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _api.markRead(id);
      await refresh(silent: true);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllRead();
      await refresh(silent: true);
    } catch (_) {}
  }

  void clearAlert() {
    if (latestAlert == null) return;
    latestAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    stop();
    super.dispose();
  }
}
