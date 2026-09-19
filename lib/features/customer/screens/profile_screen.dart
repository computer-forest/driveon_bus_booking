import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../role_select_screen.dart';
import '../widgets/customer_bottom_nav.dart';
import 'delete_account_screen.dart';
import 'home_search_screen.dart';
import 'my_bookings_screen.dart';
import 'support_screen.dart';
import 'terms_privacy_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
        (route) => false,
      );
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
    }
  }

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Text('Profile', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: AppColors.primaryTint, shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rohan Deshmukh', style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text('+91 98765 43210', style: textTheme.bodyMedium),
                        Text('rohan@example.com', style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 18, color: AppColors.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Preferences'),
            _tile(context, Icons.fingerprint_rounded, 'Biometric & PIN unlock', onTap: () {}),
            _tile(context, Icons.notifications_none_rounded, 'Notification preferences', onTap: () {}),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Support & legal'),
            _tile(
              context,
              Icons.support_agent_rounded,
              'Help & support',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
            ),
            _tile(
              context,
              Icons.description_outlined,
              'Terms & Conditions',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsPrivacyScreen(isTerms: true)),
              ),
            ),
            _tile(
              context,
              Icons.privacy_tip_outlined,
              'Privacy Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsPrivacyScreen(isTerms: false)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Account'),
            _tile(context, Icons.logout_rounded, 'Log out', onTap: () => _logout(context)),
            _tile(
              context,
              Icons.delete_outline_rounded,
              'Delete account',
              danger: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(currentIndex: 3, onTap: (i) => _onNavTap(context, i)),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, {required VoidCallback onTap, bool danger = false}) {
    final textTheme = Theme.of(context).textTheme;
    final color = danger ? AppColors.urgent : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 19, color: danger ? AppColors.urgent : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: textTheme.bodyLarge?.copyWith(color: color))),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
