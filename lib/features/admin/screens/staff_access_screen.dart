import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../../auth/data/phone.dart';

/// ADM-08: who can sign in as staff. A number on this list can sign in with
/// an OTP and gets the staff app; switching it off ends their access.
class StaffAccessScreen extends ConsumerWidget {
  const StaffAccessScreen({super.key});

  static String _last10(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, StaffMember member, bool active) async {
    if (!active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Switch off ${member.name}?'),
          content: Text('${member.name} (${member.displayPhone}) will be signed out of the staff app and will not be able to sign in as staff again until you switch them back on.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep access')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Switch off')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    await guardedWrite(context, () => ref.read(staffRepositoryProvider).setActive(member.phone, active));
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final entered = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddStaffSheet(),
    );
    if (entered == null || !context.mounted) return;
    final saved = await guardedWrite(context, () => ref.read(staffRepositoryProvider).add(phone: entered.$1, name: entered.$2));
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${entered.$2} can now sign in as staff.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final me = _last10(ref.watch(authStateProvider).value?.phone ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('Staff access')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add staff'),
      ),
      body: SafeArea(
        child: AsyncBody<List<StaffMember>>(
          value: ref.watch(staffMembersProvider),
          builder: (members) {
            final sorted = [...members]..sort((a, b) {
                if (a.active != b.active) return a.active ? -1 : 1;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
            final active = members.where((m) => m.active).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
              children: [
                Text(
                  'People on this list sign in with their mobile number and a code, and then use the staff app. $active ${active == 1 ? 'person has' : 'people have'} access.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final m in sorted) ...[
                  Builder(builder: (context) {
                    final isMe = _last10(m.phone) == me;
                    final onlyActive = m.active && active == 1;
                    final locked = isMe || onlyActive;
                    return AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(m.name, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
                                    if (isMe) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      Text('You', style: textTheme.labelMedium?.copyWith(color: AppColors.primary)),
                                    ],
                                  ],
                                ),
                                Text(m.displayPhone, style: textTheme.bodyMedium),
                                const SizedBox(height: 4),
                                if (m.active && locked)
                                  Text(
                                    isMe ? 'You cannot switch off your own access.' : 'The only person with access, so it cannot be switched off.',
                                    style: textTheme.labelSmall,
                                  )
                                else
                                  StatusBadge(label: m.active ? 'Has access' : 'Switched off', tone: m.active ? StatusTone.success : StatusTone.neutral),
                              ],
                            ),
                          ),
                          Switch(
                            value: m.active,
                            activeThumbColor: AppColors.primary,
                            onChanged: m.active && locked ? null : (v) => _toggle(context, ref, m, v),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (members.isEmpty) Text('No one is listed yet.', style: textTheme.bodyMedium),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddStaffSheet extends StatefulWidget {
  const _AddStaffSheet();

  @override
  State<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends State<_AddStaffSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _showErrors = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? get _nameError => _name.text.trim().length < 2 ? "Enter the person's name." : null;
  String? get _phoneError => Phone.validate(_phone.text);

  void _submit() {
    if (_nameError != null || _phoneError != null) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.of(context).pop((Phone.digits(_phone.text), _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add staff', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('They will sign in as staff with this number.', style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
              label: 'Name',
              controller: _name,
              errorText: _showErrors ? _nameError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
              label: 'Mobile number',
              controller: _phone,
              hint: '10-digit number',
              prefixText: '+91 ',
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              errorText: _showErrors ? _phoneError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Give staff access'))),
          ],
        ),
      ),
    );
  }
}
