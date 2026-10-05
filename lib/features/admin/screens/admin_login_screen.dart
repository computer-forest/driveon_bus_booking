import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/repositories.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _email = TextEditingController(text: 'ops@neetatravels.example');
  final _password = TextEditingController(text: '••••••••');
  bool _signingIn = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// On success the router moves the admin into their shell on its own.
  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInAdmin(_email.text.trim(), _password.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.huge, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: AppRadius.controlRadius,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'OPERATIONS CONSOLE',
                style: textTheme.labelMedium?.copyWith(letterSpacing: 0.4),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Sign in', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xxxl),
              LabeledField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.lg),
              LabeledField(label: 'Password', controller: _password, obscureText: true),
              const SizedBox(height: AppSpacing.xl),
              if (_error != null) ...[
                Text(_error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.urgent)),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                label: 'Sign in',
                loading: _signingIn,
                onPressed: _signingIn ? null : _signIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
