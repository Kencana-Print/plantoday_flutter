import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum BadgeVariant {
  primary,
  success,
  warning,
  danger,
  outline,
  neutral,
}

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final Color? customColor;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.primary,
    this.customColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    if (customColor != null) {
      bg = customColor!.withValues(alpha: 0.12);
      fg = customColor!;
      border = customColor!.withValues(alpha: 0.35);
    } else {
      switch (variant) {
        case BadgeVariant.primary:
          bg = AppColors.primary.withValues(alpha: 0.12);
          fg = AppColors.primary;
          border = AppColors.primary.withValues(alpha: 0.3);
          break;
        case BadgeVariant.success:
          bg = AppColors.success.withValues(alpha: 0.12);
          fg = AppColors.success;
          border = AppColors.success.withValues(alpha: 0.3);
          break;
        case BadgeVariant.warning:
          bg = AppColors.warning.withValues(alpha: 0.12);
          fg = AppColors.warningText;
          border = AppColors.warningBorder;
          break;
        case BadgeVariant.danger:
          bg = AppColors.danger.withValues(alpha: 0.12);
          fg = AppColors.danger;
          border = AppColors.danger.withValues(alpha: 0.3);
          break;
        case BadgeVariant.outline:
          bg = Colors.transparent;
          fg = AppColors.ink;
          border = AppColors.border;
          break;
        case BadgeVariant.neutral:
          bg = AppColors.soft;
          fg = AppColors.muted;
          border = AppColors.border;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
