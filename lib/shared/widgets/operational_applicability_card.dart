import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class OperationalApplicabilityCard extends StatelessWidget {
  const OperationalApplicabilityCard({
    required this.title,
    required this.message,
    required this.notApplicable,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String message;
  final bool notApplicable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = notApplicable ? AppColors.textSecondary : AppColors.gold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            notApplicable ? Icons.block_outlined : Icons.rule_folder_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  notApplicable ? 'Nao aplicavel nesta ocorrencia.' : message,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => onChanged(!notApplicable),
            child: Text(notApplicable ? 'Reativar' : 'Nao aplicavel'),
          ),
        ],
      ),
    );
  }
}
