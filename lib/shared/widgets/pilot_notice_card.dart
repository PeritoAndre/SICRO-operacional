import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/theme/app_theme.dart';

class PilotNoticeCard extends StatelessWidget {
  const PilotNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold),
              ),
              child: const Icon(Icons.science_outlined, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppInfo.buildLabel,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Versao para teste controlado. Os dados ficam somente neste aparelho; exporte o pacote .sicroapp antes de desinstalar ou limpar os dados do app.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
