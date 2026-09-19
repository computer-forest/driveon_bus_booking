import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_badge.dart';
import '../widgets/customer_bottom_nav.dart';
import 'booking_detail_screen.dart';
import 'home_search_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  int _tab = 0;

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
          (route) => false,
        );
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const tabs = ['Upcoming', 'Current', 'History'];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My bookings', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
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
                        margin: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: selected ? AppGradients.primary : null,
                          color: selected ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: selected
                              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tabs[i],
                          style: textTheme.labelLarge?.copyWith(
                            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: [
                    AppCard(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BookingDetailScreen()),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Thane → Mahabaleshwar', style: textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text('14 Sep 2026 · CB-20260914-0472', style: textTheme.bodyMedium),
                            ],
                          ),
                          const StatusBadge(label: 'Confirmed', tone: StatusTone.success),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mumbai → Alibaug', style: textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text('2 Oct 2026 · CB-20261002-0511', style: textTheme.bodyMedium),
                            ],
                          ),
                          const StatusBadge(label: 'Cost set', tone: StatusTone.warning),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SecondaryButton(
                      label: '+ Book a bus',
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
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
