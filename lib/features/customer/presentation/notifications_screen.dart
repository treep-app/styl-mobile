import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/notifications/notification_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_skeleton.dart';
import '../../appointments/presentation/appointment_details_sheet.dart';
import '../data/customer_demo_data.dart';

/// Compact notifications inbox — All / Unread.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  var _loading = true;
  String? _error;
  var _tab = 0; // 0 all, 1 unread
  var _markingAll = false;
  List<AppNotification> _items = const [];

  int get _unreadCount => _items.where((n) => n.unread).length;

  List<AppNotification> get _visible {
    if (_tab == 1) return _items.where((n) => n.unread).toList();
    return _items;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await context.read<AuthController>().notificationsApi.list();
      if (!mounted) return;
      setState(() {
        _items = list.map(AppNotification.fromDto).toList();
        _loading = false;
      });
      unawaited(context.read<NotificationController>().refresh(silent: true));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  AppNotification _asRead(AppNotification item) {
    return AppNotification(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      dateLabel: item.dateLabel,
      timeLabel: item.timeLabel,
      createdAt: item.createdAt,
      type: item.type,
      unread: false,
      showActions: item.showActions,
      appointmentId: item.appointmentId,
    );
  }

  void _markLocalRead(AppNotification item) {
    final i = _items.indexWhere((n) => n.id == item.id);
    if (i < 0) return;
    setState(() {
      _items = [
        ..._items.sublist(0, i),
        _asRead(item),
        ..._items.sublist(i + 1),
      ];
    });
  }

  Future<void> _onTap(AppNotification item) async {
    final auth = context.read<AuthController>();

    if (item.unread) {
      try {
        await auth.notificationsApi.markRead(item.id);
        if (!mounted) return;
        _markLocalRead(item);
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }

    if (item.isJoinRequest &&
        item.shopId != null &&
        item.shopId!.isNotEmpty) {
      await Navigator.of(context).pushNamed(
        AppRoutes.providerSalonTeam,
        arguments: SalonSetupArgs(shopId: item.shopId),
      );
      return;
    }

    if (!item.hasAppointment) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final appointment =
          await auth.appointmentsApi.getById(item.appointmentId!);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showAppointmentDetailsSheet(
        context,
        appointment: appointment,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0 || _markingAll) return;
    setState(() => _markingAll = true);
    try {
      await context.read<NotificationController>().markAllRead();
      if (!mounted) return;
      setState(() {
        _items = _items.map(_asRead).toList();
        _markingAll = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _markingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.lightCanvas,
      body: SafeArea(
        child: _loading
            ? const ColoredBox(
                color: AppColors.lightCanvas,
                child: NotificationsSkeleton(),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(canPop ? 4 : 20, 8, 12, 0),
                        child: Row(
                          children: [
                            if (canPop)
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            const Expanded(
                              child: Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ),
                            if (_unreadCount > 0)
                              TextButton(
                                onPressed: _markingAll ? null : _markAllRead,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.brandAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  _markingAll ? 'Marking…' : 'Mark all read',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _SegmentedTabs(
                          index: _tab,
                          allCount: _items.length,
                          unreadCount: _unreadCount,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: _visible.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    48,
                                    20,
                                    24,
                                  ),
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 40,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _tab == 1
                                          ? 'You’re all caught up'
                                          : 'No notifications yet',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.brandPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _tab == 1
                                          ? 'New booking updates will show here.'
                                          : 'Alerts about bookings and payments appear here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    24,
                                  ),
                                  itemCount: _visible.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = _visible[index];
                                    return _NotificationTile(
                                      item: item,
                                      onTap: () => _onTap(item),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.index,
    required this.allCount,
    required this.unreadCount,
    required this.onChanged,
  });

  final int index;
  final int allCount;
  final int unreadCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightOutlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegTab(
              label: 'All',
              count: allCount,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegTab(
              label: 'Unread',
              count: unreadCount,
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  const _SegTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleForType(item.type);
    final relative = _relativeTime(item.createdAt);

    return Material(
      color: item.unread ? const Color(0xFFFFF8F5) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.unread
                  ? const Color(0xFFFFD8C8)
                  : AppColors.lightOutlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(style.icon, size: 20, color: style.fg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          relative,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: item.unread
                            ? const Color(0xFF4B5563)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.unread) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.brandAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ] else if (item.hasAppointment) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeStyle {
  const _TypeStyle({
    required this.icon,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
}

_TypeStyle _styleForType(String type) {
  final t = type.toUpperCase();
  if (t.contains('PAID') || t.contains('PAYMENT')) {
    return const _TypeStyle(
      icon: Icons.payments_outlined,
      bg: Color(0xFFE8F5E9),
      fg: Color(0xFF2E7D32),
    );
  }
  if (t.contains('CANCEL')) {
    return const _TypeStyle(
      icon: Icons.event_busy_outlined,
      bg: Color(0xFFFFEBEE),
      fg: AppColors.error,
    );
  }
  if (t.contains('CONFIRM') || t.contains('ACCEPTED')) {
    return const _TypeStyle(
      icon: Icons.event_available_outlined,
      bg: Color(0xFFE3F2FD),
      fg: Color(0xFF1565C0),
    );
  }
  if (t.contains('REQUEST') || t.contains('PENDING') || t.contains('APPOINTMENT')) {
    return const _TypeStyle(
      icon: Icons.calendar_today_outlined,
      bg: Color(0xFFFFE8E0),
      fg: AppColors.brandAccent,
    );
  }
  return const _TypeStyle(
    icon: Icons.notifications_outlined,
    bg: Color(0xFFF2F3F7),
    fg: AppColors.brandPrimary,
  );
}

String _relativeTime(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[when.month - 1]} ${when.day}';
}
