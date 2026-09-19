import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_stepper.dart';
import '../../../data/mock_data.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/driver_card.dart';
import 'home_search_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'rating_screen.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key});

  static const _steps = ['Requested', 'Cost set', 'Confirmed', 'In trip', 'Done'];

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
          (route) => false,
        );
      case 1:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  Future<void> _requestCancellation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request cancellation?'),
        content: const Text(
          "This sends a cancellation request to our team — the booking stays active until Admin processes it.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Request')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation requested — our team will confirm shortly.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Booking detail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thane → Mahabaleshwar', style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('14 Sep 2026, 6:00 AM · Round pickup', style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: AppRadius.tagRadius,
                    ),
                    child: Text(
                      'BOOKING REF · CB-20260914-0472',
                      style: textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  StatusStepper(steps: _steps, currentIndex: 2),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionLabel('Your bus and driver'),
            AppCard(child: DriverCard(driver: MockData.driver)),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(label: 'Open GPS link', icon: Icons.location_on_outlined, onPressed: () {}),
            const SizedBox(height: AppSpacing.xxl),
            const SectionLabel('Payment'),
            AppCard(
              child: Column(
                children: [
                  for (final entry in MockData.ledger) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.label, style: textTheme.bodyLarge),
                            if (entry.note != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(entry.note!, style: textTheme.labelSmall),
                              ),
                          ],
                        ),
                        Text(
                          entry.amount,
                          style: textTheme.titleSmall?.copyWith(
                            color: entry == MockData.ledger.last ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (entry != MockData.ledger.last) const HairlineDivider(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SecondaryButton(
              label: 'Rate this trip',
              icon: Icons.star_outline_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RatingScreen())),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => _requestCancellation(context),
                child: Text('Request cancellation', style: textTheme.labelLarge?.copyWith(color: AppColors.urgent)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(currentIndex: 1, onTap: (i) => _onNavTap(context, i)),
    );
  }
}
