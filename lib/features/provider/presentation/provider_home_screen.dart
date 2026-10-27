import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/notifications/notification_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/email_capture_sheet.dart';
import '../../../widgets/styl_skeleton.dart';
import '../../customer/presentation/looks_ui.dart';
import 'provider_shell_tabs.dart';
import 'widgets/provider_looks_chrome.dart';

/// Looksy Professional Dashboard — live bookings, earnings, and shop rating.
class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  var _loading = true;
  String? _error;
  ShopDto? _shop;
  var _bookingsThisWeek = 0;
  var _earningsThisWeek = 0.0;
  String _currency = 'GBP';

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
    final auth = context.read<AuthController>();
    try {
      final appointmentsFuture = auth.appointmentsApi.list();
      final shopsFuture = auth.catalogApi.listMyShops();
      final appointments = await appointmentsFuture;
      final shops = await shopsFuture;
      if (!mounted) return;

      final shop = shops.where((s) => s.isOwner == true).firstOrNull ??
          (shops.isNotEmpty ? shops.first : null);

      final weekStart = providerWeekStart(DateTime.now());
      final weekEnd = weekStart.add(const Duration(days: 7));
      var bookings = 0;
      var earnings = 0.0;
      var currency = shop?.services.firstOrNull?.currency ?? 'GBP';

      for (final a in appointments) {
        final start = a.scheduledStart.toLocal();
        if (start.isBefore(weekStart) || !start.isBefore(weekEnd)) continue;
        if (a.status == 'CANCELLED') continue;
        bookings += 1;
        if (a.status == 'COMPLETED' || a.paymentStatus == 'PAID') {
          earnings += a.priceSnapshot;
          if (a.currency.isNotEmpty) currency = a.currency;
        }
      }

      setState(() {
        _shop = shop;
        _bookingsThisWeek = bookings;
        _earningsThisWeek = earnings;
        _currency = currency;
        _loading = false;
      });
      unawaited(context.read<NotificationController>().refresh());
      await maybePromptForEmail(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  String _greetingName(AuthController auth) {
    final full = auth.user?.fullName?.trim();
    if (full == null || full.isEmpty) return 'there';
    return full.split(RegExp(r'\s+')).first;
  }

  Future<void> _logout() async {
    await context.read<AuthController>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (route) => false,
    );
  }

  Future<void> _open(String route, [Object? args]) {
    return Navigator.of(context).pushNamed(route, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final name = _greetingName(auth);
    final shop = _shop;
    final rating = shop?.ratingAvg ?? 0;
    final reviews = shop?.ratingCount ?? 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _DashboardDrawer(
        name: auth.user?.fullName?.trim().isNotEmpty == true
            ? auth.user!.fullName!
            : 'Professional',
        salon: shop?.name,
        onSalon: () {
          Navigator.pop(context);
          _open(AppRoutes.providerManageSalon, shop?.id);
        },
        onSettings: () {
          Navigator.pop(context);
          _open(AppRoutes.providerSettings);
        },
        onHelp: () {
          Navigator.pop(context);
          _open(AppRoutes.providerHelp);
        },
        onTeam: shop == null
            ? null
            : () {
                Navigator.pop(context);
                _open(AppRoutes.providerManageSalon, shop.id);
              },
        onLogout: () {
          Navigator.pop(context);
          _logout();
        },
      ),
      body: SafeArea(
        child: _loading
            ? const ProviderHomeSkeleton()
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    color: LooksUi.purple,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      children: [
                        _TopBar(
                              unread: context
                                  .watch<NotificationController>()
                                  .unreadCount,
                              onMenu: () {
                                HapticFeedback.selectionClick();
                                _scaffoldKey.currentState?.openDrawer();
                              },
                              onBell: () async {
                                final inbox =
                                    context.read<NotificationController>();
                                await _open(AppRoutes.notifications);
                                if (!mounted) return;
                                inbox.refresh();
                              },
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Professional Dashboard',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: LooksUi.ink,
                                letterSpacing: -0.7,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Welcome back, $name!',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: LooksUi.muted,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _StatsStrip(
                              bookings: _bookingsThisWeek,
                              earningsLabel: providerMoneyLabel(
                                _earningsThisWeek,
                                currency: _currency,
                              ),
                              ratingLabel: reviews <= 0
                                  ? 'New'
                                  : rating.toStringAsFixed(1),
                              reviewsLabel: reviews <= 0
                                  ? 'No reviews yet'
                                  : '($reviews ${reviews == 1 ? 'review' : 'reviews'})',
                              onBookings: () =>
                                  ProviderShellTabs.goTo(ProviderShellTabs.calendar),
                              onEarnings: () =>
                                  _open(AppRoutes.providerAnalytics),
                              onRating: () =>
                                  _open(AppRoutes.providerAnalytics),
                            ),
                            const SizedBox(height: 18),
                            ProviderLooksMenuCard(
                              children: [
                                ProviderLooksMenuRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Manage bookings',
                                  onTap: () => _open(
                                    AppRoutes.providerAppointmentsList,
                                    const ProviderApptListArgs(),
                                  ),
                                ),
                                ProviderLooksMenuRow(
                                  icon: Icons.person_outline_rounded,
                                  label: 'My profile',
                                  onTap: () =>
                                      _open(AppRoutes.providerPersonalInfo),
                                ),
                                ProviderLooksMenuRow(
                                  icon: Icons.photo_library_outlined,
                                  label: 'Portfolio',
                                  onTap: () =>
                                      _open(AppRoutes.providerPortfolio),
                                ),
                                ProviderLooksMenuRow(
                                  icon: Icons.assignment_outlined,
                                  label: 'Services & prices',
                                  onTap: () =>
                                      _open(AppRoutes.providerServices),
                                ),
                                ProviderLooksMenuRow(
                                  icon: Icons.event_available_outlined,
                                  label: 'Availability',
                                  onTap: () =>
                                      _open(AppRoutes.providerAvailability),
                                ),
                                ProviderLooksMenuRow(
                                  icon: Icons.insights_outlined,
                                  label: 'Analytics',
                                  onTap: () =>
                                      _open(AppRoutes.providerAnalytics),
                                ),
                              ],
                            ),
                          ],
                        ),
                  ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.unread,
    required this.onMenu,
    required this.onBell,
  });

  final int unread;
  final VoidCallback onMenu;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.menu_rounded, size: 26, color: LooksUi.ink),
          ),
          const Expanded(
            child: Text(
              'STYL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: LooksUi.ink,
                letterSpacing: -0.8,
                height: 1,
              ),
            ),
          ),
          IconButton(
            onPressed: onBell,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: const Color(0xFFFF6A3D),
              smallSize: 9,
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 26,
                color: LooksUi.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.bookings,
    required this.earningsLabel,
    required this.ratingLabel,
    required this.reviewsLabel,
    required this.onBookings,
    required this.onEarnings,
    required this.onRating,
  });

  final int bookings;
  final String earningsLabel;
  final String ratingLabel;
  final String reviewsLabel;
  final VoidCallback onBookings;
  final VoidCallback onEarnings;
  final VoidCallback onRating;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F5FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatCell(
                value: '$bookings',
                label: 'Bookings',
                hint: 'this week',
                onTap: onBookings,
                animateFrom: 0,
                animateTo: bookings.toDouble(),
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              indent: 18,
              endIndent: 18,
              color: Color(0xFFE6E3EF),
            ),
            Expanded(
              child: _StatCell(
                value: earningsLabel,
                label: 'Earnings',
                hint: 'this week',
                onTap: onEarnings,
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              indent: 18,
              endIndent: 18,
              color: Color(0xFFE6E3EF),
            ),
            Expanded(
              child: _StatCell(
                value: ratingLabel,
                label: 'Rating',
                hint: reviewsLabel,
                onTap: onRating,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.hint,
    required this.onTap,
    this.animateFrom,
    this.animateTo,
  });

  final String value;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final double? animateFrom;
  final double? animateTo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            children: [
              if (animateTo != null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: animateFrom ?? 0, end: animateTo),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    return Text(
                      '${v.round()}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: LooksUi.ink,
                        height: 1.05,
                        letterSpacing: -0.6,
                      ),
                    );
                  },
                )
              else
                FittedBox(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: LooksUi.ink,
                      height: 1.05,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: LooksUi.ink,
                  height: 1.15,
                ),
              ),
              Text(
                hint,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: LooksUi.muted,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer({
    required this.name,
    required this.onSalon,
    required this.onSettings,
    required this.onHelp,
    required this.onLogout,
    this.salon,
    this.onTeam,
  });

  final String name;
  final String? salon;
  final VoidCallback onSalon;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final VoidCallback onLogout;
  final VoidCallback? onTeam;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STYL',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: LooksUi.ink,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: LooksUi.ink,
                      ),
                    ),
                    if (salon != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        salon!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: LooksUi.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: LooksUi.ink),
                title: const Text('Manage salon'),
                onTap: onSalon,
              ),
              if (onTeam != null)
                ListTile(
                  leading: const Icon(Icons.groups_outlined, color: LooksUi.ink),
                  title: const Text('Team'),
                  onTap: onTeam,
                ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: LooksUi.ink),
                title: const Text('Settings'),
                onTap: onSettings,
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: LooksUi.ink),
                title: const Text('Help'),
                onTap: onHelp,
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFD64545)),
                title: const Text(
                  'Log out',
                  style: TextStyle(color: Color(0xFFD64545)),
                ),
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 36, color: LooksUi.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: LooksUi.ink, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
