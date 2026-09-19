import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import 'profile_setup_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = 28;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 28);
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
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify number')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Code sent to +91 98765 43210', style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              PrimaryButton(
                label: 'Verify & continue',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: _secondsLeft > 0
                    ? Text('Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: textTheme.labelMedium)
                    : TextButton(onPressed: _startTimer, child: const Text('Resend code')),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.containerRadius,
                ),
                child: Text(
                  "You'll only see this step once. Next time, unlock with your fingerprint or PIN.",
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: AnimatedBuilder(
        animation: _nodes[index],
        builder: (context, child) {
          final focused = _nodes[index].hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: AppRadius.controlRadius,
              boxShadow: focused
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: child,
          );
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _nodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: ''),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              FocusScope.of(context).requestFocus(_nodes[index + 1]);
            } else if (value.isEmpty && index > 0) {
              FocusScope.of(context).requestFocus(_nodes[index - 1]);
            }
          },
        ),
      ),
    );
  }
}
