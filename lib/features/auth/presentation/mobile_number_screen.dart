import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/providers.dart';
import '../data/msg91_otp_service.dart';
import '../data/phone.dart';
import 'otp_screen.dart';

/// First step of customer sign-in: a ten-digit mobile number. The country
/// code is added in code, never typed.
///
/// With [staff] the same OTP flow signs in a staff member; the server then
/// checks the number against the staff allow-list.
class MobileNumberScreen extends ConsumerStatefulWidget {
  const MobileNumberScreen({super.key, this.staff = false});

  final bool staff;

  @override
  ConsumerState<MobileNumberScreen> createState() => _MobileNumberScreenState();
}

class _MobileNumberScreenState extends ConsumerState<MobileNumberScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _showError = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _notice = ref.read(authNoticeProvider)?.message;
    Future.microtask(() {
      if (mounted) ref.read(authNoticeProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (Phone.validate(_controller.text) != null) {
      setState(() => _showError = true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final config = ref.read(authConfigProvider);
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      final reqId = await ref
          .read(otpServiceProvider)
          .send(Phone.identifier(_controller.text, countryCode: config.countryCode));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(phone: Phone.digits(_controller.text), reqId: reqId, staff: widget.staff),
        ),
      );
    } on OtpException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        action: e.kind == OtpFailure.network ? SnackBarAction(label: 'Retry', onPressed: _continue) : null,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final config = ref.watch(authConfigProvider);
    final staff = widget.staff;
    return Scaffold(
      appBar: staff ? AppBar(title: const Text('Staff sign in')) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.huge, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: AppRadius.containerRadius,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(staff ? 'Staff sign in' : 'Book the whole bus', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                staff
                    ? 'Enter the mobile number registered for staff access. We will text you a code.'
                    : 'No seats to pick — one vehicle, confirmed by our team.',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              if (_notice != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.containerRadius),
                  child: Text(_notice!, style: textTheme.bodyMedium?.copyWith(color: AppColors.urgent)),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              LabeledField(
                label: 'Mobile number',
                controller: _controller,
                hint: '10-digit number',
                prefixText: '+${config.countryCode} ',
                keyboardType: TextInputType.phone,
                enabled: !_sending,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                errorText: _showError ? Phone.validate(_controller.text) : null,
                onChanged: (v) => setState(() => _showError = _showError || Phone.digits(v).length == 10),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(label: 'Continue', loading: _sending, onPressed: _sending ? null : _continue),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: Text(
                  'By continuing you agree to the Terms & Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium,
                ),
              ),
              if (!staff) ...[
                const SizedBox(height: AppSpacing.xxxl),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MobileNumberScreen(staff: true)),
                    ),
                    child: const Text('Staff sign in'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
