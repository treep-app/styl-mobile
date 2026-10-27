import 'package:flutter/material.dart';

import '../../../../core/network/api_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/styl_avatar.dart';

/// Compact roster card for the provider home dashboard.
class BarberRosterCard extends StatelessWidget {
  const BarberRosterCard({
    super.key,
    required this.barber,
    required this.onTap,
  });

  final SpecialistDto barber;
  final VoidCallback onTap;

  Color get _statusColor {
    if (barber.isBusy) return PresenceAvatar.busyOrange;
    if (barber.isOnline) return PresenceAvatar.onlineGreen;
    return PresenceAvatar.offlineGray;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
          child: Ink(
          width: 156,
          height: 186,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PresenceAvatar(
                size: 52,
                imageUrl: barber.avatarUrl,
                name: barber.fullName,
                isOnline: barber.isOnline,
                isBusy: barber.isBusy,
              ),
              const SizedBox(height: 10),
              Text(
                barber.fullName ?? 'Barber',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                barber.roleSpecialtyLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8A8A8A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                barber.todayScheduleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandPrimary,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      barber.statusCaption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
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
