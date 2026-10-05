import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import 'booking_detail_screen.dart';

/// The countdown here is display only. The hold's real expiry is
/// `booking.holdExpiresAt`, enforced by the backend.
class HoldScreen extends ConsumerStatefulWidget {
  const HoldScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<HoldScreen> createState() => _HoldScreenState();
}

class _HoldScreenState extends ConsumerState<HoldScreen> with SingleTickerProviderStateMixin {
  late final int _totalSeconds = ref.read(appConfigProvider).config.holdMinutes * 60;
  late int _secondsLeft = widget.booking.holdSecondsLeft(ref.read(clockProvider)());
  Timer? _timer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String get _clock {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = _totalSeconds == 0 ? 0.0 : _secondsLeft / _totalSeconds;
    final booking = widget.booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Bus held for you')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.urgentTint,
                  borderRadius: AppRadius.containerRadius,
                  boxShadow: [
                    BoxShadow(color: AppColors.urgent.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "This bus won't be given to anyone else while you're held.",
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.urgent),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        final t = _pulse.value;
                        return SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 4,
                                  backgroundColor: AppColors.urgent.withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.urgent.withValues(alpha: 0.75 + 0.25 * t),
                                  ),
                                ),
                              ),
                              Text(
                                _clock,
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppColors.urgent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${booking.capacity} seater', style: textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            '${booking.route} · ${AppDateFormat.dayMonth(booking.start)}',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const StatusBadge(label: 'Held', tone: StatusTone.warning),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.containerRadius),
                child: RichText(
                  text: TextSpan(
                    style: textTheme.bodyLarge,
                    children: [
                      TextSpan(text: 'This bus is available. ', style: textTheme.titleSmall),
                      const TextSpan(
                        text: "You'll get a call within minutes to confirm the fare. No payment is needed right now.",
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'View booking status',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
