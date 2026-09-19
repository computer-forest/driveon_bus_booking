import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';

/// BOOK-09: on trip completion the customer is prompted to rate the bus,
/// driver and overall service.
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _busRating = 0;
  int _driverRating = 0;
  int _overallRating = 0;
  final _feedbackController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _busRating > 0 && _driverRating > 0 && _overallRating > 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_submitted) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(color: AppColors.successTint, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: AppColors.success, size: 36),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Thanks for the feedback', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'It helps us keep the fleet and drivers in good shape.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SecondaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rate your trip')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            Text('Thane → Mahabaleshwar · CB-20260914-0472', style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ratingRow('Bus condition', _busRating, (v) => setState(() => _busRating = v)),
                  const SizedBox(height: AppSpacing.lg),
                  const HairlineDivider(),
                  _ratingRow('Driver', _driverRating, (v) => setState(() => _driverRating = v)),
                  const SizedBox(height: AppSpacing.lg),
                  const HairlineDivider(),
                  _ratingRow('Overall service', _overallRating, (v) => setState(() => _overallRating = v)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Feedback (optional)'),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              style: textTheme.bodyLarge,
              decoration: const InputDecoration(hintText: 'Tell us more about your trip'),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'Submit rating',
              onPressed: _canSubmit ? () => setState(() => _submitted = true) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingRow(String label, int value, ValueChanged<int> onChanged) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.titleSmall),
        Row(
          children: List.generate(5, (i) {
            final filled = i < value;
            return InkWell(
              onTap: () => onChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled ? AppColors.accent : AppColors.textTertiary,
                  size: 24,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
