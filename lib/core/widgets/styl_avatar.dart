import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/media_url.dart';

/// Profile photo circle — real image when set, otherwise initials (no stock photos).
class StylAvatar extends StatelessWidget {
  const StylAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.name,
    this.onTap,
    this.showAddBadge = false,
  });

  final double size;
  final String? imageUrl;
  final String? name;
  final VoidCallback? onTap;
  final bool showAddBadge;

  String get _initial {
    final n = name?.trim() ?? '';
    if (n.isEmpty) return '?';
    return n[0].toUpperCase();
  }

  String? get _resolvedUrl => resolveMediaUrl(imageUrl);

  bool get _hasImage {
    final url = _resolvedUrl;
    return url != null && url.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lightSurfaceVariant,
        border: Border.all(color: const Color(0xFFF0F0F0), width: 2),
      ),
      child: ClipOval(
        child: _hasImage
            ? Image.network(
                _resolvedUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => _Initials(
                  initial: _initial,
                  size: size,
                ),
              )
            : _Initials(initial: _initial, size: size),
      ),
    );

    final content = showAddBadge && !_hasImage
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: size * 0.32,
                  height: size * 0.32,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.add,
                    size: size * 0.18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          )
        : avatar;

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// Avatar with a live Online (green) / Offline (gray) status light.
class PresenceAvatar extends StatelessWidget {
  const PresenceAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.name,
    this.isOnline = false,
    this.isBusy = false,
    this.borderRadius,
  });

  final double size;
  final String? imageUrl;
  final String? name;
  final bool isOnline;
  final bool isBusy;
  /// When set, renders a rounded square instead of a circle.
  final double? borderRadius;

  static const onlineGreen = Color(0xFF34C759);
  static const offlineGray = Color(0xFFBDBDBD);
  static const busyOrange = Color(0xFFF1592A);

  Color get statusColor {
    if (isBusy) return busyOrange;
    if (isOnline) return onlineGreen;
    return offlineGray;
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius;
    final resolved = resolveMediaUrl(imageUrl);
    final hasImage = resolved != null && resolved.trim().isNotEmpty;
    final photo = radius != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: size,
              height: size,
              child: hasImage
                  ? Image.network(
                      resolved,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: AppColors.lightSurfaceVariant,
                        child: Icon(
                          Icons.person,
                          color: AppColors.brandPrimary,
                          size: size * 0.45,
                        ),
                      ),
                    )
                  : ColoredBox(
                      color: AppColors.lightSurfaceVariant,
                      child: Icon(
                        Icons.person,
                        color: AppColors.brandPrimary,
                        size: size * 0.45,
                      ),
                    ),
            ),
          )
        : StylAvatar(size: size, imageUrl: imageUrl, name: name);

    final dot = size >= 48 ? 14.0 : (size >= 36 ? 12.0 : 10.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          photo,
          Positioned(
            right: radius != null ? -1 : 2,
            bottom: radius != null ? -1 : 2,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightSurfaceVariant,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            color: AppColors.brandPrimary,
          ),
        ),
      ),
    );
  }
}
