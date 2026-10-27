import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../customer/presentation/looks_ui.dart';
import 'widgets/provider_looks_chrome.dart';

/// Honest analytics from live appointments + shop rating.
class ProviderAnalyticsScreen extends StatefulWidget {
  const ProviderAnalyticsScreen({super.key});

  @override
  State<ProviderAnalyticsScreen> createState() =>
      _ProviderAnalyticsScreenState();
}

class _ProviderAnalyticsScreenState extends State<ProviderAnalyticsScreen> {
  var _loading = true;
  String? _error;
  ShopDto? _shop;
  var _bookingsWeek = 0;
  var _bookingsAll = 0;
  var _earningsWeek = 0.0;
  var _earningsAll = 0.0;
  var _completed = 0;
  String _currency = 'GBP';
  List<int> _byWeekday = List<int>.filled(7, 0);

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
      final auth = context.read<AuthController>();
      final results = await Future.wait([
        auth.appointmentsApi.list(),
        auth.catalogApi.listMyShops(),
      ]);
      if (!mounted) return;
      final appointments = results[0] as List<AppointmentDto>;
      final shops = results[1] as List<ShopDto>;
      final shop = shops.where((s) => s.isOwner == true).firstOrNull ??
          (shops.isNotEmpty ? shops.first : null);

      final weekStart = providerWeekStart(DateTime.now());
      final weekEnd = weekStart.add(const Duration(days: 7));
      var bookingsWeek = 0;
      var earningsWeek = 0.0;
      var earningsAll = 0.0;
      var completed = 0;
      var currency = 'GBP';
      final byWeekday = List<int>.filled(7, 0);

      for (final a in appointments) {
        if (a.status == 'CANCELLED') continue;
        final start = a.scheduledStart.toLocal();
        final inWeek = !start.isBefore(weekStart) && start.isBefore(weekEnd);
        if (inWeek) bookingsWeek += 1;
        if (a.currency.isNotEmpty) currency = a.currency;
        if (a.status == 'COMPLETED' || a.paymentStatus == 'PAID') {
          completed += 1;
          earningsAll += a.priceSnapshot;
          if (inWeek) earningsWeek += a.priceSnapshot;
        }
        if (inWeek) {
          byWeekday[start.weekday - 1] += 1;
        }
      }

      setState(() {
        _shop = shop;
        _bookingsWeek = bookingsWeek;
        _bookingsAll = appointments.where((a) => a.status != 'CANCELLED').length;
        _earningsWeek = earningsWeek;
        _earningsAll = earningsAll;
        _completed = completed;
        _currency = currency;
        _byWeekday = byWeekday;
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final reviews = _shop?.ratingCount ?? 0;
    final rating = _shop?.ratingAvg ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: LooksUi.ink,
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w800, color: LooksUi.ink),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LooksUi.purple))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: LooksUi.purple,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      const Text(
                        'This week',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LooksUi.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              label: 'Bookings',
                              value: '$_bookingsWeek',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Metric(
                              label: 'Earnings',
                              value: providerMoneyLabel(
                                _earningsWeek,
                                currency: _currency,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Bookings by day',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LooksUi.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _WeekBars(counts: _byWeekday),
                      const SizedBox(height: 22),
                      const Text(
                        'All time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LooksUi.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Metric(
                        label: 'Total bookings',
                        value: '$_bookingsAll',
                      ),
                      const SizedBox(height: 10),
                      _Metric(
                        label: 'Completed',
                        value: '$_completed',
                      ),
                      const SizedBox(height: 10),
                      _Metric(
                        label: 'Earnings',
                        value: providerMoneyLabel(
                          _earningsAll,
                          currency: _currency,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Metric(
                        label: 'Rating',
                        value: reviews <= 0
                            ? 'New'
                            : '${rating.toStringAsFixed(1)} ($reviews)',
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F5FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: LooksUi.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: LooksUi.ink,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.counts});

  final List<int> counts;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _chartHeight = 148.0;
  static const _topLabelH = 14.0;
  static const _bottomLabelH = 14.0;
  static const _gapTop = 4.0;
  static const _gapBottom = 6.0;

  @override
  Widget build(BuildContext context) {
    final max = counts.fold<int>(0, math.max);
    const barMax =
        _chartHeight - _topLabelH - _bottomLabelH - _gapTop - _gapBottom;

    return SizedBox(
      height: _chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: _topLabelH,
                      child: Center(
                        child: Text(
                          '${counts[i]}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: LooksUi.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: _gapTop),
                    SizedBox(
                      height: barMax,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: max == 0
                                ? math.min(8.0, barMax)
                                : (8 + (counts[i] / max) * (barMax - 8))
                                    .clamp(0.0, barMax),
                          ),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, h, _) {
                            return Container(
                              width: double.infinity,
                              height: h,
                              decoration: BoxDecoration(
                                color: counts[i] == 0
                                    ? LooksUi.chipIdle
                                    : LooksUi.purple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: _gapBottom),
                    SizedBox(
                      height: _bottomLabelH,
                      child: Center(
                        child: Text(
                          _labels[i],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: LooksUi.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
