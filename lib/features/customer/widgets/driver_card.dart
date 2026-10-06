import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models.dart';

class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.driver});

  final DriverInfo driver;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
              color: AppColors.surface, shape: BoxShape.circle),
          child: const Icon(Icons.person_outline_rounded,
              color: AppColors.textTertiary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver.name, style: textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                  driver.phone.isEmpty
                      ? driver.busNumber
                      : '${driver.phone} · ${driver.busNumber}',
                  style: textTheme.bodyMedium),
            ],
          ),
        ),
        if (driver.phone.isNotEmpty)
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.call_outlined),
            color: AppColors.primary,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryTint,
              shape: const CircleBorder(),
            ),
          ),
      ],
    );
  }
}
