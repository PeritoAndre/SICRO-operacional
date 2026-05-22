import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class ModuleTile extends StatelessWidget {
  const ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
    this.trailingColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final Color? trailingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.gold),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 74),
                child: Container(
                  padding: trailingColor == null
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: trailingColor == null
                      ? null
                      : BoxDecoration(
                          color: trailingColor!.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: trailingColor!.withValues(alpha: 0.7),
                          ),
                        ),
                  child: Text(
                    trailingText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: trailingColor ?? AppColors.textSecondary,
                      fontSize: trailingColor == null ? null : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
