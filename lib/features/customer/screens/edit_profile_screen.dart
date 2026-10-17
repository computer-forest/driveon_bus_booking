import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// AUTH-04: change the name and email given at first sign-in. The mobile
/// number is the account itself, so it is shown but cannot be edited here.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  /// The signed-in customer as the profile screen shows them, so the form
  /// opens already filled in.
  final AppUser user;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.user.name ?? '');
  late final _email = TextEditingController(text: widget.user.email ?? '');
  late final String? _phone = widget.user.phone;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  String? get _nameError => _name.text.trim().length < 2 ? 'Enter your full name.' : null;

  /// Optional, but if given it has to look like an address.
  String? get _emailError {
    final e = _email.text.trim();
    if (e.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(e) ? null : 'That email does not look right. Check it and try again.';
  }

  Future<void> _save() async {
    if (_nameError != null || _emailError != null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final saved = await guardedWrite(
      context,
      () => ref.read(authRepositoryProvider).updateProfile(name: _name.text.trim(), email: _email.text.trim()),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            Text("So our team knows who they're calling to confirm your trip.", style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            LabeledField(
              label: 'Full name',
              controller: _name,
              enabled: !_saving,
              errorText: _showErrors ? _nameError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
              label: 'Email (optional)',
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              errorText: _showErrors ? _emailError : null,
              onChanged: (_) => setState(() {}),
            ),
            if (_phone != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.phone_iphone_rounded, size: 19, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('+91 $_phone', style: textTheme.bodyLarge),
                          Text('Your mobile number is how you sign in, so it cannot be changed here.', style: textTheme.labelMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(label: 'Save changes', loading: _saving, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
