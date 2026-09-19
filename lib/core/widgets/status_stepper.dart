import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A compact horizontal progress stepper used on the booking detail screen.
/// [currentIndex] is the active step; everything before it reads as done.
class StatusStepper extends StatelessWidget {
  const StatusStepper({super.key, required this.steps, required this.currentIndex});

  final List<String> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isEven) {
              final stepIndex = i ~/ 2;
              final done = stepIndex < currentIndex;
              final active = stepIndex == currentIndex;
              return _Dot(done: done, active: active);
            }
            final barIndex = i ~/ 2;
            final done = barIndex < currentIndex;
            return Expanded(child: _Bar(done: done));
          }),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(steps.length, (i) {
            final passed = i <= currentIndex;
            return Expanded(
              child: Text(
                steps[i],
                textAlign: i == 0
                    ? TextAlign.left
                    : (i == steps.length - 1 ? TextAlign.right : TextAlign.center),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: passed ? AppColors.textSecondary : AppColors.textTertiary,
                      fontWeight: passed ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.active});
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primary
        : (done ? AppColors.primary : AppColors.border);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: active ? 12 : 8,
      height: active ? 12 : 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: active
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 6, spreadRadius: 1)]
            : null,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 2,
      color: done ? AppColors.primary : AppColors.border,
    );
  }
}
