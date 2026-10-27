import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

const _accent = Color(0xFF4F6BFF);
const _muted = Color(0xFF8B93A7);
const _border = Color(0xFFE8EAF0);
const _successBg = Color(0xFFE8F8EF);
const _success = Color(0xFF22C55E);

/// Post-join confirmation + salon access controls for a team member.
class ProfessionalAddedScreen extends StatefulWidget {
  const ProfessionalAddedScreen({super.key, required this.args});

  final ProfessionalAddedArgs args;

  @override
  State<ProfessionalAddedScreen> createState() =>
      _ProfessionalAddedScreenState();
}

class _ProfessionalAddedScreenState extends State<ProfessionalAddedScreen> {
  late SpecialistDto _member = widget.args.specialist;
  var _savingToggle = false;

  String get _firstName {
    final parts = _member.displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? 'them' : parts.first;
  }

  String get _roleLabel {
    final specialty = _member.specialty?.trim();
    if (specialty != null && specialty.isNotEmpty) return specialty;
    return switch (_member.memberRole) {
      'OWNER' => 'Owner',
      'FREELANCER' => 'Stylist',
      _ => 'Barber',
    };
  }

  String _joinedLabel() {
    // Membership create time isn't on SpecialistDto — use a friendly fallback.
    final now = DateTime.now();
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
    return 'Joined ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Future<void> _toggleBookings(bool value) async {
    setState(() {
      _savingToggle = true;
      _member = SpecialistDto(
        id: _member.id,
        fullName: _member.fullName,
        avatarUrl: _member.avatarUrl,
        phone: _member.phone,
        email: _member.email,
        isAvailableNow: _member.isAvailableNow,
        isOnboarded: _member.isOnboarded,
        isOnline: _member.isOnline,
        isBusy: _member.isBusy,
        isOnShift: _member.isOnShift,
        presenceLabel: _member.presenceLabel,
        memberRole: _member.memberRole,
        specialty: _member.specialty,
        receiveBookings: value,
        commissionPercent: _member.commissionPercent,
        hoursLabel: _member.hoursLabel,
        workingHours: _member.workingHours,
        ratingAvg: _member.ratingAvg,
        ratingCount: _member.ratingCount,
        serviceNames: _member.serviceNames,
        nextSlot: _member.nextSlot,
      );
    });
    try {
      final updated =
          await context.read<AuthController>().catalogApi.updateShopMemberAccess(
                shopId: widget.args.shopId,
                barberUserId: _member.id,
                receiveBookings: value,
              );
      if (!mounted) return;
      setState(() {
        _member = updated;
        _savingToggle = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _member = SpecialistDto(
          id: _member.id,
          fullName: _member.fullName,
          avatarUrl: _member.avatarUrl,
          phone: _member.phone,
          email: _member.email,
          isAvailableNow: _member.isAvailableNow,
          isOnboarded: _member.isOnboarded,
          isOnline: _member.isOnline,
          isBusy: _member.isBusy,
          isOnShift: _member.isOnShift,
          presenceLabel: _member.presenceLabel,
          memberRole: _member.memberRole,
          specialty: _member.specialty,
          receiveBookings: !value,
          commissionPercent: _member.commissionPercent,
          hoursLabel: _member.hoursLabel,
          workingHours: _member.workingHours,
          ratingAvg: _member.ratingAvg,
          ratingCount: _member.ratingCount,
          serviceNames: _member.serviceNames,
          nextSlot: _member.nextSlot,
        );
        _savingToggle = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingToggle = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update booking access.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showJoinedBanner = widget.args.showJoinedBanner;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  Expanded(
                    child: Text(
                      showJoinedBanner ? 'Professional Added' : 'Team member',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (showJoinedBanner) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _successBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: _success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_member.displayName} has joined your salon! You can now manage ${_firstName.toLowerCase() == 'they' ? 'their' : 'his'} salon access.',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    children: [
                      _SquareAvatar(
                        name: _member.displayName,
                        imageUrl: _member.avatarUrl,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _member.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _roleLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: _success),
                                SizedBox(width: 6),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _joinedLabel(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Salon access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose what $_firstName can do at your salon.',
                    style: const TextStyle(fontSize: 14, color: _muted),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: _accent,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Receive bookings at this salon',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.brandPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Customers can book here.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _member.receiveBookings,
                                onChanged: _savingToggle ? null : _toggleBookings,
                                activeThumbColor: Colors.white,
                                activeTrackColor: _accent,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFF0F1F5)),
                        _NavRow(
                          icon: Icons.list_alt_outlined,
                          title: 'Assigned services',
                          subtitle: 'Manage which services $_firstName offers.',
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.providerServices,
                              arguments: ProviderServicesArgs(
                                shopId: widget.args.shopId,
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFF0F1F5)),
                        _NavRow(
                          icon: Icons.schedule_outlined,
                          title: 'Working hours',
                          subtitle:
                              "Set $_firstName's availability at this salon.",
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.providerBarberDetail,
                              arguments: ProviderBarberDetailArgs(
                                shopId: widget.args.shopId,
                                barberUserId: _member.id,
                                specialist: _member,
                                isOwner: true,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.providerSalonTeam,
                            (route) => false,
                            arguments: SalonSetupArgs(
                              shopId: widget.args.shopId,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View team',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.providerBarberDetail,
                            arguments: ProviderBarberDetailArgs(
                              shopId: widget.args.shopId,
                              barberUserId: _member.id,
                              specialist: _member,
                              isOwner: true,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandPrimary,
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: const Color(0xFFF2F3F7),
                        ),
                        child: Text(
                          "Go to $_firstName's profile",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              Icon(icon, color: _accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB0B6C3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(initial),
              )
            : _fallback(initial),
      ),
    );
  }

  Widget _fallback(String initial) {
    return ColoredBox(
      color: const Color(0xFFEDE9FE),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.brandPrimary,
            fontSize: 28,
          ),
        ),
      ),
    );
  }
}
