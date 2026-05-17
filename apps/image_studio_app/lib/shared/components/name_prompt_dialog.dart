import 'package:flutter/material.dart';

/// A short text-input dialog. The class is a [StatefulWidget] (rather than
/// an inline builder that allocates a [TextEditingController] in an async
/// function) so the controller's lifecycle is tied to the dialog element's
/// `initState` / `dispose` — which prevents the
/// `InheritedElement._dependents.isEmpty` assertion that fires when the
/// controller is disposed while the dialog's focus / material inherited
/// elements are still tearing down.
class NamePromptDialog extends StatefulWidget {
  const NamePromptDialog({
    super.key,
    required this.title,
    this.hint = '',
    this.confirmLabel = '创建',
    this.cancelLabel = '取消',
    this.initialValue = '',
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;
  final String initialValue;

  @override
  State<NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<NamePromptDialog> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_field.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Convenience wrapper around [showDialog] with a [NamePromptDialog].
Future<String?> showNamePromptDialog(
  BuildContext context, {
  required String title,
  String hint = '',
  String confirmLabel = '创建',
  String cancelLabel = '取消',
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => NamePromptDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      initialValue: initialValue,
    ),
  );
}
