import 'package:flutter/material.dart';

/// Asks for one piece of text. Returns it (possibly empty) when the person
/// confirms, or null when they back out. The dialog owns its controller, so
/// it is disposed only once the dialog is really gone.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  String cancelLabel = 'Back',
  int maxLines = 3,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextPrompt(title: title, hint: hint, confirmLabel: confirmLabel, cancelLabel: cancelLabel, maxLines: maxLines),
    );

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.maxLines,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;
  final int maxLines;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: widget.maxLines,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(widget.cancelLabel)),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text.trim()), child: Text(widget.confirmLabel)),
      ],
    );
  }
}
