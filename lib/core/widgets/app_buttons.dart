import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radius.dart';

/// Filled primary action. One per screen, ideally. Gradient fill, a soft
/// tinted shadow, and a light press-scale so it feels tactile rather than
/// flat and static.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.loading && widget.onPressed != null;
    return AnimatedScale(
      scale: _pressed && enabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: enabled ? AppGradients.primary : null,
          color: enabled ? null : AppColors.surfaceAlt,
          borderRadius: AppRadius.controlRadius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.controlRadius,
            onTap: widget.loading ? null : widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 18, color: AppColors.onPrimary),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: AppColors.onPrimary),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary action — same footprint as PrimaryButton so the two
/// can sit in a row or stack without visual jitter. Border and press-scale
/// carry the interaction instead of a fill.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedScale(
      scale: _pressed && enabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: _pressed && enabled ? AppColors.primaryTint : AppColors.background,
          borderRadius: AppRadius.controlRadius,
          border: Border.all(
            color: _pressed && enabled ? AppColors.primary : AppColors.borderStrong,
            width: 1.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.controlRadius,
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: AppColors.textPrimary),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
