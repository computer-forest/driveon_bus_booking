import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers.dart';
import '../../../core/theme/app_radius.dart';

class CustomerBottomNav extends ConsumerWidget {
  const CustomerBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.search_rounded, label: 'Search'),
    (icon: Icons.receipt_long_rounded, label: 'My bookings'),
    (icon: Icons.notifications_none_rounded, label: 'Notifications'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).items.where((n) => !n.read).length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: _NavTapTarget(
                  icon: item.icon,
                  label: item.label,
                  selected: selected,
                  badge: i == 2 ? unread : 0,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTapTarget extends StatelessWidget {
  const _NavTapTarget({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 0, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryTint : Colors.transparent,
              borderRadius: AppRadius.controlRadius,
            ),
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(icon, size: 22, color: color),
            ),
          ),
          const SizedBox(height: 3),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
