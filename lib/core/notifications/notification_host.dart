import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
import 'notification_controller.dart';

/// Hosts in-app toast banners when a new booking notification arrives.
///
/// Lives in [MaterialApp.builder], which is *above* the route [Navigator],
/// so navigation must go through [stylNavigatorKey] — not [context].
class NotificationHost extends StatefulWidget {
  const NotificationHost({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends State<NotificationHost> {
  NotificationController? _inbox;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snack;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inbox = context.read<NotificationController>();
    if (!identical(_inbox, inbox)) {
      _inbox?.removeListener(_onInbox);
      _inbox = inbox;
      _inbox!.addListener(_onInbox);
    }
  }

  @override
  void dispose() {
    _inbox?.removeListener(_onInbox);
    super.dispose();
  }

  void _openInbox() {
    final nav = stylNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamed(AppRoutes.notifications);
  }

  void _onInbox() {
    final alert = _inbox?.latestAlert;
    if (alert == null || !mounted) return;

    // Defer clear so listeners in the same frame still see the alert once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inbox?.clearAlert();
    });

    // Prefer the navigator subtree messenger (has Scaffold ancestors).
    final messenger = stylNavigatorKey.currentContext != null
        ? ScaffoldMessenger.maybeOf(stylNavigatorKey.currentContext!)
        : ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    _snack?.close();
    _snack = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFF1A1633),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              alert.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFFB8A8FF),
          onPressed: _openInbox,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep auth ↔ inbox wiring warm while the tree rebuilds.
    context.watch<AuthController>();
    return widget.child;
  }
}
