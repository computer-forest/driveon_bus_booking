import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/stage_badge.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../widgets/customer_bottom_nav.dart';
import 'booking_detail_screen.dart';
import 'home_search_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  int _tab = 0;

  static bool _inTab(int tab, BookingStage stage) {
    switch (tab) {
      case 0:
        return stage == BookingStage.requested ||
            stage == BookingStage.costConfirmed ||
            stage == BookingStage.confirmed;
      case 1:
        return stage == BookingStage.inTrip;
      default:
        return stage == BookingStage.completed || stage == BookingStage.settled;
    }
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
          (route) => false,
        );
      case 2:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      case 3:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const tabs = ['Upcoming', 'Current', 'History'];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My bookings',
                  style: textTheme.displaySmall?.copyWith(fontSize: 24)),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: List.generate(tabs.length, (i) {
                  final selected = i == _tab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        margin: EdgeInsets.only(
                            right: i == tabs.length - 1 ? 0 : AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: selected ? AppGradients.primary : null,
                          color: selected ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tabs[i],
                          style: textTheme.labelLarge?.copyWith(
                            color: selected
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: AsyncBody<List<Booking>>(
                  value: ref.watch(bookingsProvider),
                  builder: (all) {
                    final userId = ref.watch(authStateProvider).value?.id;
                    final mine = all
                        .where((b) =>
                            b.customerId == userId && _inTab(_tab, b.stage))
                        .toList()
                      ..sort((a, b) => a.start.compareTo(b.start));
                    return ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      children: [
                        if (mine.isEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Text(
                              'No ${tabs[_tab].toLowerCase()} bookings.',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        for (final booking in mine) ...[
                          AppCard(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        BookingDetailScreen(booking: booking)),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(booking.route,
                                          style: textTheme.titleSmall),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${AppDateFormat.dayMonthYear(booking.start)} · ${booking.reference}',
                                        style: textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                StageBadge(booking.stage),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        SecondaryButton(
                          label: '+ Book a bus',
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const HomeSearchScreen()),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(currentIndex: 1, onTap: _onNavTap),
    );
  }
}
