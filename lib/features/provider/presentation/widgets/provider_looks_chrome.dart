import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../customer/presentation/looks_ui.dart';

/// Shared Looksy chrome for professional screens.
class ProviderLooksPage extends StatelessWidget {
  const ProviderLooksPage({
    super.key,
    required this.title,
    required this.child,
    this.onRefresh,
    this.trailing,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Future<void> Function()? onRefresh;
  final Widget? trailing;
  /// When set, shows a back chevron above the title (e.g. pushed routes).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(onBack != null ? 4 : 20, 4, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: LooksUi.ink,
                    tooltip: 'Back',
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(onBack != null ? 16 : 0, 0, 0, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: LooksUi.ink,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: LooksUi.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );

    if (onRefresh == null) {
      return ColoredBox(color: Colors.white, child: body);
    }

    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        color: LooksUi.purple,
        onRefresh: onRefresh!,
        child: body,
      ),
    );
  }
}

class ProviderLooksMenuCard extends StatelessWidget {
  const ProviderLooksMenuCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LooksUi.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A1633),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 56,
                  color: LooksUi.hairline,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProviderLooksMenuRow extends StatelessWidget {
  const ProviderLooksMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: LooksUi.ink),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: LooksUi.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: LooksUi.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: LooksUi.navGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String providerMoneyLabel(double amount, {String currency = 'GBP'}) {
  final symbol = switch (currency) {
    'GBP' => '£',
    'USD' => '\$',
    'EUR' => '€',
    _ => '$currency ',
  };
  if (amount == 0) return '${symbol}0';
  if (amount == amount.roundToDouble()) {
    return '$symbol${amount.round()}';
  }
  return '$symbol${amount.toStringAsFixed(2)}';
}

DateTime providerDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime providerWeekStart(DateTime d) {
  final day = providerDay(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool providerSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
