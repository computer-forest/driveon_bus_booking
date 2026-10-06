import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_body.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// NOTIF-04: the in-app inbox, shared by customers and staff. Tapping an
/// entry marks it read and, if it is about a booking we can find, opens it
/// through [onOpenBooking].
class NotificationList extends ConsumerWidget {
  const NotificationList({super.key, required this.onOpenBooking});

  final void Function(Booking booking) onOpenBooking;

  static Color toneColor(NotificationTone tone) {
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

  static IconData toneIcon(NotificationTone tone) {
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

  void _open(WidgetRef ref, AppNotification n) {
    if (!n.read) ref.read(notificationRepositoryProvider).markRead(n.id).catchError((Object _) {});
    final id = n.bookingId;
    if (id == null) return;
    final booking = ref.read(bookingsProvider).items.where((b) => b.id == id).firstOrNull;
    if (booking != null) onOpenBooking(booking);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    return AsyncBody<List<AppNotification>>(
      value: ref.watch(notificationsProvider),
      builder: (notifications) {
        if (notifications.isEmpty) {
          return Center(child: Text("You're all caught up.", style: textTheme.bodyMedium));
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final n = notifications[i];
            final color = toneColor(n.tone);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(ref, n),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: n.read ? AppColors.background : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(toneIcon(n.tone), size: 18, color: color),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(n.title, style: textTheme.titleSmall)),
                              if (!n.read)
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(n.body, style: textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text(AppDateFormat.ago(n.createdAt, now), style: textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
