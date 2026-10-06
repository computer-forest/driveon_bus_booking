import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/repositories.dart';
import '../../customer/screens/profile_setup_screen.dart';
import '../data/auth_messages.dart';
import '../data/msg91_otp_service.dart';
import '../data/phone.dart';
import 'enable_biometric_screen.dart';

/// Second step of sign-in. One hidden field holds the code and the boxes
/// just display it, so typing, backspace, paste and SMS autofill all behave.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, required this.reqId, this.staff = false});

  /// Ten digits, no country code.
  final String phone;
  final String reqId;

  /// Signing in as staff: the number must be on the staff allow-list.
  final bool staff;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  late int _secondsLeft;
  late final String _reqId = widget.reqId;
  bool _verifying = false;
  bool _resending = false;
  bool _blocked = false;
  String? _error;

  int get _length => ref.read(authConfigProvider).otpLength;
  bool get _busy => _verifying || _resending;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = ref.read(authConfigProvider).resendCooldown.inSeconds);
    if (_secondsLeft == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  void _allowResendNow() {
    _timer?.cancel();
    _secondsLeft = 0;
  }

  void _onChanged(String value) {
    setState(() => _error = null);
    if (value.length == _length && !_blocked && !_busy) _verify();
  }

  Future<void> _verify() async {
    if (_field.text.length != _length || _blocked || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final token = await ref.read(otpServiceProvider).verify(reqId: _reqId, otp: _field.text);
      final user = await ref
          .read(authRepositoryProvider)
          .signInWithOtpToken(phone: widget.phone, accessToken: token, staff: widget.staff);
      if (!mounted) return;
      // Staff have no customer profile to fill in.
      final needsProfile = !user.isAdmin && (user.name ?? '').isEmpty;
      await navigator.pushReplacement(MaterialPageRoute(
        builder: (_) => needsProfile ? const ProfileSetupScreen() : const EnableBiometricScreen(),
      ));
    } on OtpException catch (e) {
      if (!mounted) return;
      _field.clear();
      setState(() {
        _error = e.message;
        if (e.kind == OtpFailure.tooManyAttempts) _blocked = true;
        if (e.kind == OtpFailure.expired || e.kind == OtpFailure.tooManyAttempts) _allowResendNow();
      });
    } on AuthException catch (e) {
      // MSG91 accepted the code but the server would not let this number in
      // (not verified, or not on the staff list): back to the number screen.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      navigator.pop();
    } catch (_) {
      // The code was accepted but this phone could not save the sign-in
      // (e.g. secure storage unavailable). A used code cannot be reused.
      if (!mounted) return;
      _field.clear();
      setState(() {
        _error = AuthMessages.sessionNotSaved;
        _allowResendNow();
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend(int channel) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(otpServiceProvider).retry(reqId: _reqId, channel: channel);
      if (!mounted) return;
      _field.clear();
      _blocked = false;
      _startTimer();
      messenger.showSnackBar(SnackBar(
        content: Text(channel == OtpChannel.voice ? 'You will get a call with the code shortly.' : 'We sent you a new code.'),
      ));
    } on OtpException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final config = ref.watch(authConfigProvider);
    final canVerify = _field.text.length == config.otpLength && !_blocked && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify number')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Code sent to +${config.countryCode} ${Phone.pretty(widget.phone)}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Edit number'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _OtpBoxes(
                controller: _field,
                focusNode: _focus,
                length: config.otpLength,
                hasError: _error != null,
                enabled: !_verifying && !_blocked,
                onChanged: _onChanged,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_error != null) ...[
                Text(_error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.urgent)),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                label: 'Verify & continue',
                loading: _verifying,
                onPressed: canVerify ? _verify : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: _secondsLeft > 0
                    ? Text('Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}', style: textTheme.labelMedium)
                    : Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _resend(OtpChannel.sms),
                            child: const Text('Resend via SMS'),
                          ),
                          if (config.voiceRetryEnabled)
                            TextButton(
                              onPressed: _busy ? null : () => _resend(OtpChannel.voice),
                              child: const Text('Get a call'),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.containerRadius),
                child: Text(
                  "You'll only see this step once. Next time, unlock with your fingerprint or face.",
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, focusNode]),
                builder: (context, _) {
                  final code = controller.text;
                  final active = focusNode.hasFocus ? code.length.clamp(0, length - 1) : -1;
                  return Row(
                    children: [
                      for (var i = 0; i < length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.controlRadius,
                              border: Border.all(
                                color: hasError
                                    ? AppColors.urgent
                                    : i == active
                                        ? AppColors.primary
                                        : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                            child: Text(
                              i < code.length ? code[i] : '',
                              style: textTheme.headlineSmall?.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          // The real field sits on top, invisible, so taps and paste reach it.
          Positioned.fill(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: true,
              showCursor: false,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration.collapsed(hintText: null),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
