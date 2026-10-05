import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_body.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../widgets/customer_bottom_nav.dart';
import 'home_search_screen.dart';
import 'my_bookings_screen.dart';

/// NOTIF-04: in-app notification inbox mirroring every push, with read
/// state and (in the real app) deep links into the booking.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Color _toneColor(NotificationTone tone) {
    switch (tone) {
      case NotificationTone.success:
        return AppColors.success;
      case NotificationTone.warning:
        return AppColors.warning;
      case NotificationTone.urgent:
        return AppColors.urgent;
      case NotificationTone.info:
        return AppColors.info;
    }
  }

  IconData _toneIcon(NotificationTone tone) {
    switch (tone) {
      case NotificationTone.success:
        return Icons.check_circle_rounded;
      case NotificationTone.warning:
        return Icons.hourglass_bottom_rounded;
      case NotificationTone.urgent:
        return Icons.error_rounded;
      case NotificationTone.info:
        return Icons.info_rounded;
    }
  }

  void _onNavTap(BuildContext context, int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
        (route) => false,
      );
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifications',
                  style: textTheme.displaySmall?.copyWith(fontSize: 24)),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: AsyncBody<List<AppNotification>>(
                  value: ref.watch(notificationsProvider),
                  builder: (notifications) => ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) {
                      final n = notifications[i];
                      final color = _toneColor(n.tone);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: n.read
                            ? null
                            : () => ref
                                .read(notificationRepositoryProvider)
                                .markRead(n.id),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: n.read
                                ? AppColors.background
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle),
                                child: Icon(_toneIcon(n.tone),
                                    size: 18, color: color),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                            child: Text(n.title,
                                                style: textTheme.titleSmall)),
                                        if (!n.read)
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(n.body, style: textTheme.bodyMedium),
                                    const SizedBox(height: 4),
                                    Text(AppDateFormat.ago(n.createdAt, now),
                                        style: textTheme.labelSmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(
          currentIndex: 2, onTap: (i) => _onNavTap(context, i)),
    );
  }
}
