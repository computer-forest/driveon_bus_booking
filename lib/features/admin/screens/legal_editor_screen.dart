import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/async_body.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// ADM-11: staff write the Terms & Conditions or the Privacy Policy as
/// headed sections. Customers see exactly this, with the date it was saved.
class LegalEditorScreen extends ConsumerWidget {
  const LegalEditorScreen({super.key, required this.kind});

  final LegalKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(kind.title)),
      body: SafeArea(
        child: AsyncBody<LegalDocument?>(
          value: ref.watch(legalProvider(kind)),
          // Built once from what is stored; later saves by someone else do not
          // overwrite what is being typed here.
          builder: (doc) => _Editor(kind: kind, initial: doc),
        ),
      ),
    );
  }
}

class _Draft {
  _Draft({String heading = '', String body = ''})
      : heading = TextEditingController(text: heading),
        body = TextEditingController(text: body);

  final TextEditingController heading;
  final TextEditingController body;

  void dispose() {
    heading.dispose();
    body.dispose();
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.kind, required this.initial});

  final LegalKind kind;
  final LegalDocument? initial;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final List<_Draft> _drafts = [
    for (final s in widget.initial?.sections ?? const <LegalSection>[]) _Draft(heading: s.heading, body: s.body),
  ];
  bool _saving = false;

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  /// Sections with neither a heading nor text are dropped, so an accidental
  /// empty block does not reach customers.
  List<LegalSection> get _sections => [
        for (final d in _drafts)
          if (d.heading.text.trim().isNotEmpty || d.body.text.trim().isNotEmpty)
            LegalSection(heading: d.heading.text.trim(), body: d.body.text.trim()),
      ];

  Future<void> _save() async {
    setState(() => _saving = true);
    final sections = _sections;
    final saved = await guardedWrite(context, () => ref.read(contentRepositoryProvider).saveLegal(widget.kind, sections));
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.kind.title} saved. Customers see it now.')));
    }
  }

  void _remove(int i) {
    setState(() => _drafts.removeAt(i).dispose());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
      children: [
        Text(
          'Write each part with a heading and its text. Customers see these in order, with the date you save.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_drafts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text('Nothing here yet. Until you add text, customers are told this is being finalised.', style: textTheme.labelMedium),
          ),
        for (var i = 0; i < _drafts.length; i++) ...[
          AppCard(
            key: ValueKey(_drafts[i]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Section ${i + 1}', style: textTheme.labelMedium)),
                    IconButton(
                      tooltip: 'Remove section',
                      onPressed: _saving ? null : () => _remove(i),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ),
                TextField(
                  controller: _drafts[i].heading,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Heading, e.g. Payments and cancellations'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _drafts[i].body,
                  minLines: 4,
                  maxLines: 14,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Text of this section'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SecondaryButton(
          label: 'Add a section',
          icon: Icons.add_rounded,
          onPressed: _saving ? null : () => setState(() => _drafts.add(_Draft())),
        ),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(label: 'Save ${widget.kind.title}', loading: _saving, onPressed: _saving ? null : _save),
      ],
    );
  }
}
