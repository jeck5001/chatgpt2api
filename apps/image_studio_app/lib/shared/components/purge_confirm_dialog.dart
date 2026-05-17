import 'package:flutter/material.dart';

/// Confirm dialog with an opt-in "also purge server images" checkbox.
///
/// Returns `null` if cancelled; otherwise returns the purge flag (`true` if
/// the user opted in to also delete the underlying image files on the
/// server, `false` if they confirmed only the studio-side removal).
///
/// The class is a [StatefulWidget] so the checkbox state stays bound to the
/// dialog element's lifecycle rather than to an async closure.
class PurgeConfirmDialog extends StatefulWidget {
  const PurgeConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.purgeLabel = '同时从服务器删除已生成的图片',
    this.purgeHint = '勾选后将无法在网页后台或图片库中再看到这些图片。',
    this.confirmLabel = '删除',
    this.cancelLabel = '取消',
    this.initialPurge = false,
  });

  final String title;
  final String message;
  final String purgeLabel;
  final String purgeHint;
  final String confirmLabel;
  final String cancelLabel;
  final bool initialPurge;

  @override
  State<PurgeConfirmDialog> createState() => _PurgeConfirmDialogState();
}

class _PurgeConfirmDialogState extends State<PurgeConfirmDialog> {
  late bool _purge = widget.initialPurge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _purge = !_purge),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _purge,
                    onChanged: (value) =>
                        setState(() => _purge = value ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(widget.purgeLabel),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.purgeHint,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.of(context).pop(_purge),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

Future<bool?> showPurgeConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String purgeLabel = '同时从服务器删除已生成的图片',
  String purgeHint = '勾选后将无法在网页后台或图片库中再看到这些图片。',
  String confirmLabel = '删除',
  String cancelLabel = '取消',
  bool initialPurge = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => PurgeConfirmDialog(
      title: title,
      message: message,
      purgeLabel: purgeLabel,
      purgeHint: purgeHint,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      initialPurge: initialPurge,
    ),
  );
}
