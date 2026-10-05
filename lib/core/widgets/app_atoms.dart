import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Hairline-bordered container with a soft ambient shadow for lift.
/// Tappable cards get a light press-scale so they read as interactive.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.background,
      borderRadius: AppRadius.containerRadius,
      border: Border.all(color: _pressed ? AppColors.borderStrong : AppColors.border),
      boxShadow: const [
        BoxShadow(color: Color(0x0F13131A), blurRadius: 20, offset: Offset(0, 6)),
      ],
    );

    if (widget.onTap == null) {
      return Container(padding: widget.padding, decoration: decoration, child: widget.child);
    }

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Container(
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.containerRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Small section heading used above a group of fields or rows. Sentence
/// case, medium weight, secondary colour — no tracked-out caps.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary);
    if (trailing == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: style),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(text, style: style, overflow: TextOverflow.ellipsis)),
          Flexible(child: trailing!),
        ],
      ),
    );
  }
}

/// Label-above-field text input, consistent across every form in the app.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.initialValue,
    this.onChanged,
    this.obscureText = false,
    this.errorText,
    this.inputFormatters,
    this.prefixText,
    this.enabled = true,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          enabled: enabled,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixText: prefixText,
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, size: 19, color: AppColors.textTertiary)
                : null,
          ),
        ),
      ],
    );
  }
}

/// A thin horizontal rule used between rows inside a card, instead of
/// nesting further bordered containers.
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider(height: AppSpacing.xl);
}
