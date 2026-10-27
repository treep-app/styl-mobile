import 'package:flutter/material.dart';

import '../../data/provider_demo_data.dart';

/// Appointment card matching Figma Total / Open / Closed list rows.
class ProviderAppointmentTile extends StatelessWidget {
  const ProviderAppointmentTile({
    super.key,
    required this.appointment,
    this.onTap,
  });

  final ProviderAppointment appointment;
  final VoidCallback? onTap;

  static const _openBorder = Color(0xFFFFD8C8);
  static const _openGlow = Color(0xFFFFE8DE);
  static const _openIcon = Color(0xFFF1592A);

  static const _doneBorder = Color(0xFFC8E6C9);
  static const _doneGlow = Color(0xFFE8F5E9);
  static const _doneIcon = Color(0xFF66BB6A);

  static const _cancelBorder = Color(0xFFFFCDD2);
  static const _cancelGlow = Color(0xFFFFEBEE);
  static const _cancelIcon = Color(0xFFEF5350);

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(appointment.kind);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: style.border, width: 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFF2F3F7),
                backgroundImage: appointment.avatarUrl != null
                    ? NetworkImage(appointment.avatarUrl!)
                    : null,
                onBackgroundImageError: appointment.avatarUrl != null
                    ? (_, _) {}
                    : null,
                child: appointment.avatarUrl == null
                    ? const Icon(Icons.person, color: Color(0xFF9E9E9E))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      appointment.clientName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.timeRange,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8D8D8D),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                glow: style.glow,
                color: style.icon,
                icon: style.iconData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _TileStyle _styleFor(ProviderApptKind kind) {
    switch (kind) {
      case ProviderApptKind.opened:
        return const _TileStyle(
          border: _openBorder,
          glow: _openGlow,
          icon: _openIcon,
          iconData: Icons.access_time_filled,
        );
      case ProviderApptKind.completed:
        return const _TileStyle(
          border: _doneBorder,
          glow: _doneGlow,
          icon: _doneIcon,
          iconData: Icons.check,
        );
      case ProviderApptKind.cancelled:
        return const _TileStyle(
          border: _cancelBorder,
          glow: _cancelGlow,
          icon: _cancelIcon,
          iconData: Icons.close,
        );
    }
  }
}

class _TileStyle {
  const _TileStyle({
    required this.border,
    required this.glow,
    required this.icon,
    required this.iconData,
  });

  final Color border;
  final Color glow;
  final Color icon;
  final IconData iconData;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.glow,
    required this.color,
    required this.icon,
  });

  final Color glow;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: glow, shape: BoxShape.circle),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
