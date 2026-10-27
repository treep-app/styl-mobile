import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/styl_avatar.dart';
import '../features/customer/data/customer_demo_data.dart';

/// Shared salon / freelancer card used on Home and Barber list.
class SalonListCard extends StatelessWidget {
  const SalonListCard({
    super.key,
    required this.salon,
    required this.onTap,
    this.expanded = false,
  });

  final SalonPreview salon;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.lightOutlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              salon.kind == ProviderKind.freelancer
                  ? PresenceAvatar(
                      size: expanded ? 100 : 72,
                      imageUrl: salon.imageUrl,
                      name: salon.name,
                      isOnline: salon.isOnline,
                      borderRadius: AppRadii.sm,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: SizedBox(
                        width: expanded ? 100 : 88,
                        height: expanded ? 100 : 72,
                        child: salon.imageUrl != null
                            ? Image.network(
                                salon.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => ColoredBox(
                                  color: AppColors.lightSurfaceVariant,
                                  child: Icon(
                                    Icons.storefront_outlined,
                                    color: AppColors.brandPrimary,
                                    size: 32,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: AppColors.lightSurfaceVariant,
                                child: Icon(
                                  Icons.storefront_outlined,
                                  color: AppColors.brandPrimary,
                                  size: 32,
                                ),
                              ),
                      ),
                    ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            salon.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFFFFC107),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          salon.rating.toStringAsFixed(1),
                          style: context.textStyles.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      salon.subtitle,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 4),
                      Text(
                        salon.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodySmall,
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        salon.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      salon.distance,
                      style: context.textStyles.labelSmall?.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    if (salon.kind == ProviderKind.freelancer) ...[
                      const SizedBox(height: 4),
                      Text(
                        salon.isOnline
                            ? 'Online'
                            : (salon.isOnboarded
                                ? 'Offline'
                                : 'Unlinked · Offline'),
                        style: context.textStyles.labelSmall?.copyWith(
                          color: salon.isOnline
                              ? PresenceAvatar.onlineGreen
                              : AppColors.lightOnSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
