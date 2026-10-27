import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_skeleton.dart';
import '../data/payments_api.dart';

/// Payments — saved cards + booking payment activity (no wallet balance).
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  var _loading = true;
  String? _error;
  List<PaymentMethodDto> _methods = const [];
  List<PaymentTransactionDto> _transactions = const [];

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
    final payments = context.read<AuthController>().paymentsApi;
    try {
      final results = await Future.wait([
        payments.listMethods().catchError((_) => <PaymentMethodDto>[]),
        payments.listTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _methods = results[0] as List<PaymentMethodDto>;
        _transactions = results[1] as List<PaymentTransactionDto>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
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

  Future<void> _addCard() async {
    final result = await Navigator.of(context).pushNamed(AppRoutes.addCard);
    if (result != null && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        context.watch<AuthController>().user?.fullName?.trim().isNotEmpty ==
                true
            ? context.watch<AuthController>().user!.fullName!
            : 'Card holder';

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: _loading
            ? const PaymentsSkeleton()
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF575757)),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.brandPrimary,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        const Text(
                          'Payments',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cards you use for bookings, and your recent payment activity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Color(0xFF8A8A8A),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _SectionHeader(
                          title: 'Payment methods',
                          actionLabel: 'Add card',
                          onAction: _addCard,
                        ),
                        const SizedBox(height: 12),
                        if (_methods.isEmpty)
                          _EmptyMethods(onAdd: _addCard)
                        else
                          ..._methods.map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SavedCardRow(
                                brand: m.brand,
                                last4: m.last4,
                                expMonth: m.expMonth,
                                expYear: m.expYear,
                                holderName: userName,
                                isDefault: m.isDefault,
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        const _SectionHeader(title: 'Activity'),
                        const SizedBox(height: 4),
                        if (_transactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              'No payments yet.\nBook and pay to see activity here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                          )
                        else
                          ...List.generate(_transactions.length, (i) {
                            final tx = _transactions[i];
                            final isLast = i == _transactions.length - 1;
                            return Column(
                              children: [
                                _ActivityRow(tx: tx),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFF0F0F0),
                                  ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyMethods extends StatelessWidget {
  const _EmptyMethods({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_card_outlined, size: 28, color: AppColors.brandPrimary),
            SizedBox(height: 10),
            Text(
              'Add a card',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Saved securely with Stripe for faster checkout',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF8A8A8A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedCardRow extends StatelessWidget {
  const _SavedCardRow({
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.holderName,
    this.isDefault = false,
  });

  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final String holderName;
  final bool isDefault;

  String get _brandLabel {
    final b = brand.trim();
    if (b.isEmpty) return 'Card';
    return b[0].toUpperCase() + b.substring(1).toLowerCase();
  }

  String get _expiry {
    if (expMonth < 1 || expYear < 1) return '';
    final yy = (expYear % 100).toString().padLeft(2, '0');
    return '${expMonth.toString().padLeft(2, '0')}/$yy';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _brandLabel.length > 4 ? _brandLabel.substring(0, 4) : _brandLabel,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•••• $last4',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    holderName,
                    if (_expiry.isNotEmpty) 'Exp $_expiry',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ],
            ),
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF5FB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Default',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.tx});

  final PaymentTransactionDto tx;

  Color get _statusColor {
    switch (tx.status.toUpperCase()) {
      case 'PAID':
        return const Color(0xFF1B7A3D);
      case 'UNPAID':
        return const Color(0xFFB26A00);
      case 'REFUNDED':
        return const Color(0xFF6B6B6B);
      default:
        return const Color(0xFF575757);
    }
  }

  String get _methodLabel {
    switch (tx.paymentMethod.toUpperCase()) {
      case 'WALLET':
        return 'Card';
      case 'CARD':
        return 'Card';
      case 'CASH':
        return 'Cash';
      case 'PAYPAL':
        return 'PayPal';
      default:
        return tx.paymentMethod;
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
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
    return '${local.day} ${months[local.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (tx.subtitle != null && tx.subtitle!.isNotEmpty)
                      tx.subtitle!,
                    _formatDate(tx.createdAt),
                    _methodLabel,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tx.amountLabel.replaceFirst(RegExp(r'^[+-]'), ''),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tx.status.toUpperCase() == 'PAID'
                    ? 'Paid'
                    : tx.status.toUpperCase() == 'UNPAID'
                        ? 'Unpaid'
                        : tx.status,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
